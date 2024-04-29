#!/bin/bash

# Variables
ISOLATED_PF_CONF="/etc/pf.conf.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.pfisolation.plist"
LOG_FILE="/Library/Ossec/logs/active-responses.log"

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
log_message "active-response/bin/unisolation.sh: Endpoint unisolated."

echo "Endpoint unisolated."
