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
    
    # Define the XML content to be inserted
    local xml_content="\
    <!-- Isolation timestamp -->\n\
    <labels>\n\
      <label key=\"isolated.time\">$timestamp</label>\n\
    </labels>"

    # Use awk to find the line number of the closing ossec_config tag
    local closing_tag_line=$(awk '/<\/ossec_config>/ {print NR}' "$file_path")
    
    # Insert the XML content before the closing ossec_config tag
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
    
    # Define PF rules to allow connections only for the specified IP address and port
    rules_content="block all\npass in inet proto tcp from any to $ip port $port\npass out inet proto tcp from $ip port $port to any"
    
    # Create the pf rules file for isolation
    echo -e "$rules_content" | tee "$ISOLATED_PF_CONF" > /dev/null
    
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
    local ip port
    ip_port=$(read_ip_and_port_from_file "$OSSEC_CONF")
    ip=$(echo "$ip_port" | cut -d' ' -f1)
    port=$(echo "$ip_port" | cut -d' ' -f2)

    # Apply PF rules and make them persistent
    apply_and_persist_pf_rules "$ip" "$port"

    # Update ossec.conf with current timestamp
    update_config_file_with_timestamp "$OSSEC_CONF" "$(date +"%Y-%m-%d %H:%M:%S")"

    log_message "active-response/bin/isolation.sh: Endpoint Isolated."
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

# Load the Launch Agent
launchctl load "$LAUNCHDAEMONS_FILE"
