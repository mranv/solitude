#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
IPTABLES_RULES_FILE="/etc/iptables/rules.v4"
RESTORE_SCRIPT="/etc/iptables/restore.sh"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/iptables-restore.service"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Install iptables-persistent to manage rules (optional based on your preference)
 apt-get update
 apt-get install iptables-persistent -y

# Create iptables directory if not exists
mkdir -p /etc/iptables

# Function to read IP address and port from the file
read_ip_and_port_from_file() {
    local file_path=$1
    local ip
    local port

    # Read IP address and port from the file
    while IFS= read -r line; do
        if [[ $line =~ "<address>" ]]; then
            ip=$(echo "$line" | sed -e 's/.*<address>\(.*\)<\/address>.*/\1/')
        elif [[ $line =~ "<port>" ]]; then
            port=$(echo "$line" | sed -e 's/.*<port>\(.*\)<\/port>.*/\1/')
        elif [[ $line =~ "</server>" ]]; then
            # If both address and port are found, break
            if [[ -n $ip && -n $port ]]; then
                break
            fi
        fi
    done < "$file_path"

    echo "$ip" "$port"
}

# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path=$1
    local timestamp=$2

    # Find the position to insert the label
    local insertion_point=$(grep -b -m 1 "</ossec_config>" "$file_path" | cut -d ':' -f 1)

    # Insert the label with the timestamp
    sed -i "${insertion_point}i\\
    <labels>\\
      <label key=\"isolated.time\">${timestamp}</label>\\
    </labels>" "$file_path"
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Function to apply iptables rules and save them
apply_and_save_iptables_rules() {
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

    # Allow outgoing connections to the specified IP address and port
    iptables -A OUTPUT -p tcp -d "$ip" --dport "$port" -j ACCEPT

    # Allow loopback access
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Log iptables denied calls (optional)
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables INPUT denied: " --log-level 7
    iptables -A OUTPUT -m limit --limit 5/min -j LOG --log-prefix "iptables OUTPUT denied: " --log-level 7

    # Save iptables rules to persist after reboot
    iptables-save > "$IPTABLES_RULES_FILE"
}

# Main function
main() {
    # Read IP address and port from the file
    local ip port
    read_ip_and_port_from_file "/var/ossec/etc/ossec.conf"
    ip="$1"
    port="$2"

    # Get the current time as timestamp
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update the configuration file with the timestamp
    update_config_file_with_timestamp "/var/ossec/etc/ossec.conf" "$current_time"

    # Apply iptables rules and save them
    apply_and_save_iptables_rules

    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
}

# Function to set and save iptables rules
setup_iptables() {
    # Define isolation rules here
    iptables -F
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p tcp -d "$ip" --dport "$port" -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Save the rules
    iptables-save > "$IPTABLES_RULES_FILE"
}

# Function to create iptables restore script
create_restore_script() {
    echo '#!/bin/sh' > "$RESTORE_SCRIPT"
    echo "/sbin/iptables-restore < $IPTABLES_RULES_FILE" >> "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

# Function to setup systemd service for iptables
setup_systemd_service() {
    echo '[Unit]' > "$SYSTEMD_SERVICE_FILE"
    echo 'Description=Restore iptables rules on boot' >> "$SYSTEMD_SERVICE_FILE"
    echo 'After=network.target' >> "$SYSTEMD_SERVICE_FILE"
    echo '' >> "$SYSTEMD_SERVICE_FILE"
    echo '[Service]' >> "$SYSTEMD_SERVICE_FILE"
    echo 'Type=oneshot' >> "$SYSTEMD_SERVICE_FILE"
    echo "ExecStart=$RESTORE_SCRIPT" >> "$SYSTEMD_SERVICE_FILE"
    echo 'RemainAfterExit=yes' >> "$SYSTEMD_SERVICE_FILE"
    echo '' >> "$SYSTEMD_SERVICE_FILE"
    echo '[Install]' >> "$SYSTEMD_SERVICE_FILE"
    echo 'WantedBy=multi-user.target' >> "$SYSTEMD_SERVICE_FILE"

    systemctl enable iptables-restore.service
    systemctl start iptables-restore.service
}

# Main execution flow
main "$@"
setup_iptables
create_restore_script
setup_systemd_service

echo "Iptables isolation setup and systemd service have been configured."
