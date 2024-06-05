#!/bin/bash

# Variables
LOG_FILE="/var/ossec/logs/active-responses.log"
DISK="/dev/sdX"  # Replace with your disk identifier
MAPPED_NAME="encrypted_disk"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
    local log_entry="$timestamp $message"
    echo "$log_entry" | tee -a "$LOG_FILE" > /dev/null
}

# Function to update label based on encrypt or decrypt
update_label() {
    local file_path="$1"
    local action="$2"  # "encrypt" or "decrypt"
    local label_value=$( [ "$action" = "encrypt" ] && echo "encrypted" || echo "normal" )
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

    # Backup the original file before modifications
    cp "$file_path" "$file_path.bak"

    # Process the file to correctly update or insert the encryption labels before </ossec_config>
    awk -v label_value="$label_value" -v timestamp="$timestamp" '
    BEGIN { printing = 1; labels_printed = 0; }
    /<\/ossec_config>/ {
        if (!labels_printed) {
            print "  <!-- Encryption timestamp -->";
            print "  <labels>";
            print "    <label key=\"encryption_state\">" label_value "</label>";
            print "    <label key=\"encryption_time\">" timestamp "</label>";
            print "  </labels>";
            labels_printed = 1;
        }
        print "</ossec_config>";
        printing = 0;
        next;
    }
    /<!-- Encryption timestamp -->/,/<\/labels>/ {
        if (/<!-- Encryption timestamp -->/) {
            print;  # Print the comment marking the start of the encryption info
            next;
        }
        if (/<labels>/) {
            print;
            next;
        }
        if (/<\/labels>/) {
            if (!labels_printed) {
                print "    <label key=\"encryption_state\">" label_value "</label>";
                print "    <label key=\"encryption_time\">" timestamp "</label>";
                labels_printed = 1;
            }
            print;
            next;
        }
        if ($0 ~ /<label key="encryption_state">|<label key="encryption_time">/) {
            next; # Skip existing encryption labels
        }
        print; # Print all other labels unconditionally
        next;
    }
    printing { print }
    ' "$file_path.bak" > "$file_path"

    echo "File updated with $action status at path: $file_path"
}

encrypt_disk() {
    # Encrypt the disk
    echo "Encrypting disk $DISK"
    sudo cryptsetup luksFormat "$DISK"
    sudo cryptsetup luksOpen "$DISK" "$MAPPED_NAME"
    sudo mkfs.ext4 /dev/mapper/"$MAPPED_NAME"
    sudo cryptsetup luksClose "$MAPPED_NAME"
    log_message "Disk $DISK encrypted."
    update_label "$OSSEC_CONF" "encrypt"
}

# Main Execution
encrypt_disk

exit 0
