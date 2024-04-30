#!/bin/bash

# Variables
ISOLATED_PF_CONF="/etc/pf.conf.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.pfisolation.plist"
LOG_FILE="/Library/Ossec/logs/active-responses.log"
OSSEC_CONF="/Library/Ossec/etc/ossec.conf"


# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path="$1"
    local timestamp="$2"
    
    # Define the XML content to be inserted
    local xml_content="\
    \n\
    <!-- Unisolation timestamp -->\n\
    <labels>\n\
      <label key=\"unisolated.time\">$timestamp</label>\n\
    </labels>"

    # Use awk to find the line number of the closing ossec_config tag
    local closing_tag_line=$(awk '/<\/ossec_config>/ {print NR}' "$file_path")
    
    # Insert the XML content before the closing ossec_config tag
    awk -v content="$xml_content" -v line="$closing_tag_line" 'NR==line-1 {print content} {print}' "$file_path" > "$file_path.tmp" && mv "$file_path.tmp" "$file_path"
    
    echo "File updated with timestamp at path: $file_path"
}


# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Disable PF
sudo pfctl -d

# Restore default PF rules (assuming default is less restrictive)
sudo pfctl -f /etc/pf.conf

# Unload and remove the Launch Agent
sudo launchctl unload "$LAUNCHDAEMONS_FILE"
sudo rm "$LAUNCHDAEMONS_FILE"

# Log unisolation event
log_message "active-response/bin/unisolation.sh: Endpoint Unisolated."


    update_config_file_with_timestamp "$OSSEC_CONF" "$(date +"%Y-%m-%d %H:%M:%S")"

