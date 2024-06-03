#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
RULES_FILE="/etc/udev/rules.d/11-to_rule_all.rules"
ALLOW_RULE="ACTION==\"add\", DRIVERS==\"usb\""
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Function to update label based on isolation or unisolation
update_label() {
    local file_path="$1"
    local action="$2"  # "isolate" or "unisolate"
    local label_value=$( [ "$action" = "isolate" ] && echo "isolated" || echo "normal" )
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

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

unblock_usb_perm() {
    if [ -f "$RULES_FILE" ]; then
        echo "$ALLOW_RULE" | sudo tee "$RULES_FILE" > /dev/null
        sudo rm -rf "$RULES_FILE"
        log_message "USB ports permanently unblocked."
        update_label "$OSSEC_CONF" "unisolate"
    else
        echo "USB ports are not blocked."
    fi
}

unblock_usb_perm

exit 0
