#!/bin/bash

# Variables
LOG_FILE="/Library/Ossec/logs/active-responses.log"
ISOLATED_HOSTS_FILE="/etc/hosts.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.hostsisolation.plist"
OSSEC_CONF="/Library/Ossec/etc/ossec.conf"
DOMAINS=("www.example1.com" "www.example2.com" "www.example3.com")

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

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to update /etc/hosts with domains to block
update_hosts_file() {
    local action="$1"  # "isolate" or "unisolate"
    
    if [ "$action" = "isolate" ]; then
        echo "Backing up current /etc/hosts file to $ISOLATED_HOSTS_FILE.bak"
        cp /etc/hosts "$ISOLATED_HOSTS_FILE.bak"
        
        echo "Updating /etc/hosts to block specific domains"
        for domain in "${DOMAINS[@]}"; do
            echo "127.0.0.1 $domain" >> /etc/hosts
        done
    elif [ "$action" = "unisolate" ]; then
        echo "Restoring original /etc/hosts file from backup"
        cp "$ISOLATED_HOSTS_FILE.bak" /etc/hosts
    fi
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
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Main function
main() {
    # Update /etc/hosts to block specific domains
    update_hosts_file "isolate"
    
    # Update ossec.conf with the current action
    update_label "$OSSEC_CONF" "isolate"
    
    # Log isolation event
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
  <string>com.user.hostsisolation</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>cp $ISOLATED_HOSTS_FILE /etc/hosts</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

# Load the Launch Daemon
launchctl load "$LAUNCHDAEMONS_FILE"
