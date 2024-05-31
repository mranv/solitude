#!/bin/bash

# Variables
LOG_FILE="/Library/Ossec/logs/active-responses.log"
ISOLATED_PF_CONF="/etc/pf.conf.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.pfisolation.plist"
OSSEC_CONF="/Library/Ossec/etc/ossec.conf"

# Function to update label based on isolation or unisolation
update_label() {
    local file_path="$1"
    local action="$2"  # "isolate" or "unisolate"
    local label_value=$( [ "$action" = "isolate" ] && echo "isolated" || echo "normal" )
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

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

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to read IP address and port from file
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

# Function to apply PF rules and make them persistent
apply_and_persist_pf_rules() {
    local ip="$1"
    local port="$2"

    # Define PF rules to allow connections only for the specified IP address and ports
    rules_content="block all
    pass in inet proto tcp from $ip to any port { $port, 1515 }
    pass in inet proto udp from $ip to any port { $port }
    pass out inet proto tcp from any to $ip port { $port, 1515 }
    pass out inet proto udp from any to $ip port { $port }"

    # Create the pf rules file for isolation
    echo "$rules_content" > "$ISOLATED_PF_CONF"

    # Load the isolation rules
    pfctl -f "$ISOLATED_PF_CONF"

    # Enable PF
    pfctl -e
}

# Function to restart Wazuh Agent
restart_wazuh_agent() {
    # Unload and load the Wazuh agent using launchctl
    launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist
    sleep 5
    launchctl load /Library/LaunchDaemons/com.wazuh.agent.plist
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Main function
main() {
    # Read IP address and port from the file
    local ip port
    ip_port=$(read_ip_and_port_from_file "$OSSEC_CONF")
    ip=$(echo "$ip_port" | cut -d' ' -f1)
    port=$(echo "$ip_port" | cut -d' ' -f2)

    # Apply PF rules and make them persistent
    apply_and_persist_pf_rules "$ip" "$port"
    
    # Update ossec.conf with the current action
    update_label "$OSSEC_CONF" "isolate"
    
    # Log unisolation event
    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
    
    # Restarting Wazuh Agent
    restart_wazuh_agent
}

# Call the main function
main

# Create a Launch Agent to persist the settings
tee "$LAUNCHDAEMONS_FILE" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.pfisolation</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>pfctl -f $ISOLATED_PF_CONF; pfctl -e</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

# Load the Launch Daemon
launchctl load "$LAUNCHDAEMONS_FILE"