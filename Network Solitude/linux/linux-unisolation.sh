#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/iptables-restore.service"
RULES_FILE="/etc/iptables/rules.v4"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to remove or create rules file
remove_or_create_rules_file() {
    if [ -f "$RULES_FILE" ]; then
        rm "$RULES_FILE"
    else
        touch "$RULES_FILE"
    fi
}

# Function to update label based on isolation or unisolation
update_label() {
    local file_path="$1"
    local action="$2"  # "isolate" or "unisolate"
    local label_value=$( [ "$action" = "isolate" ] && echo "isolated" || echo "normal" )

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

# Function to remove systemd service
remove_systemd_service() {
    if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
        systemctl stop iptables-restore.service
        systemctl disable iptables-restore.service
        rm "$SYSTEMD_SERVICE_FILE"
    fi
}

# Function to restart Wazuh Agent
restart_wazuh_agent() {
    systemctl restart wazuh-agent
    echo "Wazuh agent restarted."
}

# Main function
main() {
    # Remove or create rules file
    remove_or_create_rules_file

    # Flush existing iptables rules to start fresh
    iptables -F
    iptables -X
    iptables -Z

    # Configure iptables for default policy
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT

    # Remove systemd service
    remove_systemd_service

    # Update ossec.conf with the current action
    update_label "$OSSEC_CONF" "unisolate"

    # Log unisolation event
    log_message "active-response/bin/unisolation.sh: Endpoint Unisolated."

    # Restart Wazuh Agent
    restart_wazuh_agent
}

# Execute the main function
main
