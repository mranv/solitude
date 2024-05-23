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
    awk '/<!-- Isolation timestamp -->/,/<\/labels>/ { if (/isolated\.time/) nextblock=1; next } !nextblock {print} {nextblock=0}' "$file_path.bak" > "$file_path"

    # Define the new XML content to be inserted
    local xml_content="\\n\
    <!-- Isolation timestamp -->\n\
    <labels>\n\
      <label key=\"isolated.time\">$timestamp</label>\n\
    </labels>"

    # Use awk to find the line number of the closing ossec_config tag
    local closing_tag_line=$(awk '/<\/ossec_config>/ {print NR}' "$file_path")
    
    # Insert the new XML content before the closing ossec_config tag
    awk -v content="$xml_content" -v line="$closing_tag_line" 'NR==line-1 {print content} {print}' "$file_path" > "$file_path.tmp" && mv "$file_path.tmp" "$file_path"
    
    echo "File updated with timestamp at path: $file_path"
}

# Function to read IP address from file
read_ip_from_file() {
    local file_path="$1"
    local ip

    # Read IP address from the file
    while IFS= read -r line; do
        if [[ $line =~ "<address>" ]]; then
            ip=$(echo "$line" | sed -e 's/.*<address>\(.*\)<\/address>.*/\1/' | tr -d '[:space:]')
            break
        fi
    done < "$file_path"

    echo "$ip"
}

# Function to apply PF rules and make them persistent
apply_and_persist_pf_rules() {
    local ip="$1"
    
    # Define PF rules to allow all traffic for the specified IP address
    rules_content="block all\npass in inet from any to $ip\npass out inet from $ip to any"
    
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
    # Read IP address from the file
    local ip
    ip=$(read_ip_from_file "$OSSEC_CONF")

    # Apply PF rules and make them persistent
    apply_and_persist_pf_rules "$ip"

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