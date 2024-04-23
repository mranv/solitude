#!/bin/bash

# Variables
LOG_FILE="/Library/Ossec/logs/active-responses.log"
PF_CONF_FILE="/etc/pf.conf"
RULES_FILE="/etc/pf.anchors/custom_rules.pf"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.custom.pf.rules.plist"
SCRIPT_PATH="/Users/mranv/Desktop/infopercept/solitude/mac-unisolation.sh"  # Path where the script was moved

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to remove the timestamp label from the configuration file
remove_timestamp_from_config() {
    local file_path="$1"
    
    # Remove the label containing the timestamp
    sed -i '' '/<labels>/,/<\/labels>/d' "$file_path"
    
    echo "Timestamp label removed from file: $file_path"
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

# Function to remove the custom PF rules and restore the original configuration
remove_pf_rules() {
    # Remove the custom rules from the PF configuration file
    sed -i '' '/# Custom PF Rules/,/^$/d' "$PF_CONF_FILE"
    echo "Custom PF rules removed from $PF_CONF_FILE."

    # Reload the PF configuration
    /sbin/pfctl -f "$PF_CONF_FILE"
    echo "PF configuration reloaded."
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

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Main function
main() {
    # Remove the timestamp label from the configuration file
    remove_timestamp_from_config "/Library/Ossec/etc/ossec.conf"

    # Disable PF firewall
    disable_pf

    # Remove the custom PF rules
    remove_pf_rules

    # Enable PF firewall
    enable_pf

    log_message "active-response/bin/unisolation.sh: Endpoint Unisolated."
}

# Call the main function
main

# Unload the Launch Daemon
launchctl unload "$LAUNCHDAEMONS_FILE"

# Remove the Launch Daemon plist file
rm "$LAUNCHDAEMONS_FILE"

# Remove the script from the persistent location
rm "$SCRIPT_PATH"

echo "Unisolation script executed successfully."
