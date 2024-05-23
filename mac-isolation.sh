#!/bin/bash

# Variables
LOG_FILE="/Library/Ossec/logs/active-responses.log"
ISOLATED_PF_CONF="/etc/pf.conf.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.pfisolation.plist"
OSSEC_CONF="/Library/Ossec/etc/ossec.conf"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path="$1"
    local timestamp="$2"

    # Backup the original file before modifications
    cp "$file_path" "$file_path.bak"

    # Remove only the <labels> sections that have the isolated.time key using awk
    awk '/<!-- Isolation timestamp -->/,/<\/labels>/ { if (/isolated\_time/) nextblock=1; next } !nextblock {print} {nextblock=0}' "$file_path.bak" > "$file_path"

    # Define the new XML content to be inserted
    local xml_content="\\n\\
<!-- Isolation timestamp -->\\n\\
<labels>\\n\\
	<label key=\"isolation_state\”>isolated</label>\\n\\
	<label key=\"isolation_time\">$timestamp</label>\\n\\
</labels>

    # Use awk to find the line number of the closing ossec_config tag
    local closing_tag_line=$(awk '/<\/ossec_config>/ {print NR}' "$file_path")

    # Insert the new XML content before the closing ossec_config tag
    awk -v content="$xml_content" -v line="$closing_tag_line" 'NR==line-1 {print content} {print}' "$file_path" > "$file_path.tmp" && mv "$file_path.tmp" "$file_path"

    echo "File updated with timestamp at path: $file_path"
}

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
    echo -e "$rules_content" > "$ISOLATED_PF_CONF"

    # Load the isolation rules
    pfctl -f "$ISOLATED_PF_CONF"

    # Enable PF
    pfctl -e
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
    local ip_port
    ip_port=$(read_ip_and_port_from_file "$OSSEC_CONF")
    local ip=$(echo "$ip_port" | cut -d' ' -f1)
    local port=$(echo "$ip_port" | cut -d' ' -f2)

    # Apply PF rules and make them persistent
    apply_and_persist_pf_rules "$ip" "$port"

    # Update ossec.conf with current timestamp
    update_config_file_with_timestamp "$OSSEC_CONF" "$(date +"%Y-%m-%d %H:%M:%S")"

    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
}

# Call the main function
main

# Create a Launch Daemon to persist the settings
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

/Library/Ossec/bin/wazuh-control restart
