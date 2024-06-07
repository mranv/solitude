#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
IPTABLES_RULES_FILE="/etc/iptables/rules.v4"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/iptables-restore.service"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Create iptables directory if not exists
mkdir -p /etc/iptables

# Function to update label based on isolation or unisolation
update_label() {
    local file_path="$1"
    local action="$2"  # "isolate" or "unisolate"
    local label_value=$( [ "$action" = "isolate" ] && echo "isolated" || echo "normal" )
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Backup the original file before modifications
    cp "$file_path" "$file_path.bak"

    # Process the file to correctly update or insert the isolation labels before </ossec_config>
    awk -v label_value="$label_value" -v timestamp="$timestamp" '
    BEGIN { printing = 1; labels_printed = 0; }
    /<\/ossec_config>/ {
        if (!labels_printed) {
            print "  <!-- Isolation timestamp -->";
            print "  <labels>";
            print "    <label key=\"isolation_state\">" label_value "</label>";
            print "    <label key=\"isolation_time\">" timestamp "</label>";
            print "  </labels>";
            labels_printed = 1;
        }
        print "</ossec_config>";
        printing = 0;
        next;
    }
    /<!-- Isolation timestamp -->/,/<\/labels>/ {
        if (/<!-- Isolation timestamp -->/) {
            print;  # Print the comment marking the start of the isolation info
            next;
        }
        if (/<labels>/) {
            print;
            next;
        }
        if (/<\/labels>/) {
            if (!labels_printed) {
                print "    <label key=\"isolation_state\">" label_value "</label>";
                print "    <label key=\"isolation_time\">" timestamp "</label>";
                labels_printed = 1;
            }
            print;
            next;
        }
        if ($0 ~ /<label key="isolation_state">|<label key="isolation_time">/) {
            next; # Skip existing isolation labels
        }
        print; # Print all other labels unconditionally
        next;
    }
    printing { print }
    ' "$file_path.bak" > "$file_path"

    echo "File updated with $action status at path: $file_path"
}

# Function to read IP address and port from the file
read_ip_and_port_from_file() {
    local file_path="$1"
    local ip
    local port

    # Read IP address and port from the file
    while IFS= read -r line; do
        if [[ $line =~ "<address>" ]]; then
            ip=$(echo "$line" | sed -e 's/.*<address>\(.*\)<\/address>.*/\1/' | tr -d '[:space:]')
        elif [[ $line =~ "<port>" ]]; then
            port=$(echo "$line" | sed -e 's/.*<port>\(.*\)<\/port>.*/\1/' | tr -d '[:space:]')
        elif [[ $line =~ "</server>" ]]; then
            # If both address and port are found, break
            if [[ -n $ip && -n $port ]]; then
                break
            fi
        fi
    done < "$file_path"

    echo "$ip $port"
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Function to apply iptables rules and save them
apply_and_save_iptables_rules() {
    local ip="$1"
    local port="$2"

    # Flush existing iptables rules to start fresh
    iptables -F
    iptables -X
    iptables -Z

    # Default policy: drop all incoming and outgoing traffic
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    # Allow established and related incoming connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow incoming connections from the specified IP address to port 1515 and specified port
    iptables -A INPUT -p tcp -s "$ip" --dport 1515 -j ACCEPT
    iptables -A INPUT -p udp -s "$ip" --dport 1515 -j ACCEPT
    iptables -A INPUT -p tcp -s "$ip" --dport "$port" -j ACCEPT
    iptables -A INPUT -p udp -s "$ip" --dport "$port" -j ACCEPT

    # Allow outgoing connections to the specified IP address and ports
    iptables -A OUTPUT -p tcp -d "$ip" --dport 1515 -j ACCEPT
    iptables -A OUTPUT -p udp -d "$ip" --dport 1515 -j ACCEPT
    iptables -A OUTPUT -p tcp -d "$ip" --dport "$port" -j ACCEPT
    iptables -A OUTPUT -p udp -d "$ip" --dport "$port" -j ACCEPT

    # Allow loopback access (necessary for local process communication)
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Save iptables rules to persist after reboot
    iptables-save > "$IPTABLES_RULES_FILE"
}

# Function to create iptables restore script
create_restore_script() {
    local restore_script="/etc/iptables/restore.sh"
    echo '#!/bin/sh' > "$restore_script"
    echo "/sbin/iptables-restore < $IPTABLES_RULES_FILE" >> "$restore_script"
    chmod +x "$restore_script"
}

# Function to setup systemd service for iptables
setup_systemd_service() {
    local systemd_service_file="/etc/systemd/system/iptables-restore.service"
    echo '[Unit]' > "$systemd_service_file"
    echo 'Description=Restore iptables rules on boot' >> "$systemd_service_file"
    echo 'After=network.target' >> "$systemd_service_file"
    echo '' >> "$systemd_service_file"
    echo '[Service]' >> "$systemd_service_file"
    echo 'Type=oneshot' >> "$systemd_service_file"
    echo "ExecStart=/etc/iptables/restore.sh" >> "$systemd_service_file"
    echo 'RemainAfterExit=yes' >> "$systemd_service_file"
    echo '' >> "$systemd_service_file"
    echo '[Install]' >> "$systemd_service_file"
    echo 'WantedBy=multi-user.target' >> "$systemd_service_file"

    systemctl enable iptables-restore.service
    systemctl start iptables-restore.service
}

# Function to restart Wazuh Agent
restart_wazuh_agent() {
    systemctl restart wazuh-agent
    echo "Wazuh agent restarted."
}

# Main function
main() {
    # Read IP address and port from the file
    local ip_port
    ip_port=$(read_ip_and_port_from_file "$OSSEC_CONF")
    local ip=$(echo "$ip_port" | cut -d' ' -f1)
    local port=$(echo "$ip_port" | cut -d' ' -f2)

    # Apply iptables rules and save them
    apply_and_save_iptables_rules "$ip" "$port"
    
    # Update ossec.conf with the current action
    update_label "$OSSEC_CONF" "isolate"
    
    # Log isolation event
    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
    
    # Create iptables restore script and systemd service
    create_restore_script
    setup_systemd_service

    # Restart Wazuh Agent
    restart_wazuh_agent
}

# Execute the main function
main