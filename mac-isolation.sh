#!/bin/bash

# Variables
LOG_FILE="/Library/Ossec/logs/active-responses.log"
RULES_FILE="/etc/pf.anchors/custom_rules.pf"
PF_CONF_FILE="/etc/pf.conf"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.custom.pf.rules.plist"
SCRIPT_PATH="/Users/mranv/Desktop/infopercept/solitude/mac-isolation.sh"  # Path where the script will be moved

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

# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path="$1"
    local timestamp="$2"
    
    if ! content=$(<"$file_path"); then
        echo "Failed to read file at path: $file_path"
        return 1
    fi
    
    insertion_point=$(echo "$content" | grep -b -o "</ossec_config>" | cut -d':' -f1)
    
    if [ -z "$insertion_point" ]; then
        echo "Insertion point not found in file at path: $file_path"
        return 1
    fi
    
    new_content="\n<labels>\n  <label key=\"isolated.time\">$timestamp</label>\n</labels>\n"
    sed -i '' "${insertion_point}i\\$new_content" "$file_path"
    
    echo "File updated with timestamp at path: $file_path"
}

# Function to disable pf firewall
disable_pf() {
    echo "Disabling Packet Filter firewall..."
    /sbin/pfctl -d
    if [ $? -eq 0 ]; then
        echo "Packet Filter firewall disabled."
    else
        echo "Failed to disable Packet Filter firewall."
    fi
}

# Function to enable pf firewall
enable_pf() {
    echo "Enabling Packet Filter firewall..."
    /sbin/pfctl -e
    if [ $? -eq 0 ]; then
        echo "Packet Filter firewall enabled."
    else
        echo "Failed to enable Packet Filter firewall."
    fi
}

# Function to apply PF rules and make them persistent
apply_and_persist_pf_rules() {
    local ip="$1"
    local port="$2"
    
    # Define PF rules to allow connections only for the specified IP address and port
    rules_content="block all\npass in inet proto tcp from any to $ip port $port\npass out inet proto tcp from $ip port $port to any"
    
    # Update PF configuration file with the rules
    echo -e "\n# Custom PF Rules" >> "$PF_CONF_FILE"
    echo -e "$rules_content" >> "$PF_CONF_FILE"
    
    # Reload PF configuration to apply the new rules
    /sbin/pfctl -f "$PF_CONF_FILE"
    
    echo "PF rules applied and updated in $PF_CONF_FILE."
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Main function
main() {
    # Read IP address and port from the file
    local ip port
    ip_port=$(read_ip_and_port_from_file "/Library/Ossec/etc/ossec.conf")
    ip=$(echo "$ip_port" | cut -d' ' -f1)
    port=$(echo "$ip_port" | cut -d' ' -f2)

    # Get the current time as timestamp
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%S")

    # Update the configuration file with the timestamp
    update_config_file_with_timestamp "/Library/Ossec/etc/ossec.conf" "$current_time"

    # Disable PF firewall
    disable_pf

    # Apply PF rules and update PF configuration file
    apply_and_persist_pf_rules "$ip" "$port"

    # Enable PF firewall
    enable_pf

    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
}

# Call the main function
main

# Move the script to a persistent location
cp "$0" "$SCRIPT_PATH"

# Create Launch Daemon plist file
cat << EOF > "$LAUNCHDAEMONS_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.custom.pf.rules</string>
    <key>Program</key>
    <string>$SCRIPT_PATH</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the Launch Daemon
launchctl load "$LAUNCHDAEMONS_FILE"

echo "Script made persistent and configured to run at boot."
