#!/bin/bash

# Variables
ISOLATED_HOSTS_FILE="/etc/hosts.isolated"
LAUNCHDAEMONS_FILE="/Library/LaunchDaemons/com.user.hostsisolation.plist"
LOG_FILE="/Library/Ossec/logs/active-responses.log"
OSSEC_CONF="/Library/Ossec/etc/ossec.conf"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to update label based on isolation or unisolation
update_label() {
    local file_path="$1"
    local action="$2"  # "isolate" or "unisolate"
    local label_value=$( [ "$action" = "isolate" ] && echo "isolated" || echo "normal" )
    # local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Backup the original file before modifications
    cp "$file_path" "$file_path.bak"

    # Process the file to correctly update or insert the isolation labels before </ossec_config>
    awk -v label_value="$label_value" '
    BEGIN { printing = 1; labels_printed = 0; }
    /<\/ossec_config>/ {
        if (!labels_printed) {
            print "  <!-- Isolation timestamp -->";
            print "  <labels>";
            print "    <label key=\"isolation_state\">" label_value "</label>";
            # print "    <label key=\"isolation_time\">" timestamp "</label>";
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
                # print "    <label key=\"isolation_time\">" timestamp "</label>";
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

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="$timestamp $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Function to restart Wazuh Agent
restart_wazuh_agent() {
    # Unload and load the Wazuh agent using launchctl
    launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist
    sleep 5
    launchctl load /Library/LaunchDaemons/com.wazuh.agent.plist
}

# Main unisolation process
main() {
    # Restore original hosts file
    if [ -f "$ISOLATED_HOSTS_FILE.bak" ]; then
        cp "$ISOLATED_HOSTS_FILE.bak" /etc/hosts
        echo "Original /etc/hosts file restored."
    else
        echo "Backup hosts file not found. No changes made."
    fi

    # Unload and remove the Launch Agent
    sudo launchctl unload "$LAUNCHDAEMONS_FILE"
    sudo rm "$LAUNCHDAEMONS_FILE"

    # Update ossec.conf with the current action
    update_label "$OSSEC_CONF" "unisolate"

    # Log unisolation event
    log_message "active-response/bin/unisolation.sh: Endpoint Unisolated."

    # Restarting Wazuh Agent
    restart_wazuh_agent
}

# Call the main function
main
