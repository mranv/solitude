#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
OSSEC_CONF="/var/ossec/etc/ossec.conf"
DOMAIN_BLOCK_RULE="127.0.0.1"
DOMAIN_TO_BLOCK="example.com"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Function to update label based on block or unblock
update_label() {
    local file_path="$1"
    local action="$2"  # "block" or "unblock"
    local label_value=$( [ "$action" = "block" ] && echo "blocked" || echo "normal" )
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

    # Backup the original file before modifications
    cp "$file_path" "$file_path.bak"

    # Process the file to correctly update or insert the block labels before </ossec_config>
    awk -v label_value="$label_value" -v timestamp="$timestamp" '
    BEGIN { printing = 1; labels_printed = 0; }
    /<\/ossec_config>/ {
        if (!labels_printed) {
            print "  <!-- Block timestamp -->";
            print "  <labels>";
            print "    <label key=\"block_state\">" label_value "</label>";
            print "    <label key=\"block_time\">" timestamp "</label>";
            print "  </labels>";
            labels_printed = 1;
        }
        print "</ossec_config>";
        printing = 0;
        next;
    }
    /<!-- Block timestamp -->/,/<\/labels>/ {
        if (/<!-- Block timestamp -->/) {
            print;  # Print the comment marking the start of the block info
            next;
        }
        if (/<labels>/) {
            print;
            next;
        }
        if (/<\/labels>/) {
            if (!labels_printed) {
                print "    <label key=\"block_state\">" label_value "</label>";
                print "    <label key=\"block_time\">" timestamp "</label>";
                labels_printed = 1;
            }
            print;
            next;
        }
        if ($0 ~ /<label key="block_state">|<label key="block_time">/) {
            next; # Skip existing block labels
        }
        print; # Print all other labels unconditionally
        next;
    }
    printing { print }
    ' "$file_path.bak" > "$file_path"

    echo "File updated with $action status at path: $file_path"
}

block_domain() {
    # Add domain block rule
    echo "$DOMAIN_BLOCK_RULE $DOMAIN_TO_BLOCK" | sudo tee -a /etc/hosts > /dev/null
    log_message "Domain $DOMAIN_TO_BLOCK blocked."
    update_label "$OSSEC_CONF" "block"
}

# Main Execution
block_domain

exit 0
