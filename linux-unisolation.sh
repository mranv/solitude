#!/bin/bash

LOG_FILE="/var/ossec/logs/active-responses.log"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/iptables-restore.service"
RULES_FILE="/etc/iptables/rules.v4"

# Function to remove /etc/iptables/rules.v4 if present, otherwise create an empty file
remove_or_create_rules_file() {
    if [ -f "$RULES_FILE" ]; then
        rm "$RULES_FILE"
    else
        touch "$RULES_FILE"
    fi
}

# Function to read IP address and port from the file
read_ip_and_port_from_file() {
    local file_path="$1"
    local ip
    local port

    # Read IP address and port from the file
    while IFS= read -r line; do
        if [[ $line =~ "<address>" ]]; then
            ip=$(echo "$line" | sed -e 's/.*<address>\(.*\)<\/address>.*/\1/')
        elif [[ $line =~ "<port>" ]]; then
            port=$(echo "$line" | sed -e 's/.*<port>\(.*\)<\/port>.*/\1/')
        elif [[ $line =~ "</server>" ]]; then
            # If both address and port are found, break
            if [[ -n $ip && -n $port ]]; then
                break
            fi
        fi
    done < "$file_path"

    echo "$ip" "$port"
}

# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path="$1"
    local timestamp="$2"

    # Insert the label with the timestamp at the end of ossec_config
    sed -i "/<\/ossec_config>/i \
    <labels>\\
      <label key=\"unisolated.time\">${timestamp}</label>\\
    </labels>" "$file_path"
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date +"%a %b %d %T %Z %Y")
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

# Main function
main() {
    # Remove or create /etc/iptables/rules.v4
    remove_or_create_rules_file

    # Read IP address and port from the file
    read_ip_and_port_from_file "/var/ossec/etc/ossec.conf"
    local ip="$1"
    local port="$2"

    # Get the current time as timestamp
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update the configuration file with the timestamp
    update_config_file_with_timestamp "/var/ossec/etc/ossec.conf" "$current_time"

    # Log message and print configure iptables message
    local configure_iptables_msg="active-response/bin/unisolation.sh: Endpoint unisolated."
    log_message "$configure_iptables_msg"
    echo "$configure_iptables_msg"

    # Remove systemd service
    remove_systemd_service
}

# Execute the main function
main "$@"
