#!/bin/bash

# Function to read IP address and port from file
read_ip_and_port_from_file() {
    local file_path="$1"
    local content
    content=$(<"$file_path")
    
    local ip_range
    ip_range=$(echo "$content" | grep -oPm 1 '<address>\K(.*?)(?=</address>)')
    
    local port_range
    port_range=$(echo "$content" | grep -oPm 1 '<port>\K(.*?)(?=</port>)')
    
    echo "$ip_range $port_range"
}

# Function to update configuration file with timestamp
update_config_file_with_timestamp() {
    local file_path="$1"
    local timestamp
    timestamp=$(date +'%Y-%m-%dT%H:%M:%S')
    
    sed -i -e "/<\/ossec_config>/i \ \n<labels>\n  <label key=\"unisolated.time\">$timestamp<\/label>\n<\/labels>\n" "$file_path"
}

# Function to disable pf firewall
disable_pf() {
    /sbin/pfctl -d
}

# Function to enable pf firewall
enable_pf() {
    /sbin/pfctl -e
}

# Main function
main() {
    local ip port
    read_ip_and_port_from_file "/Library/Ossec/etc/ossec.conf"
    ip="$1"
    port="$2"

    update_config_file_with_timestamp "/Library/Ossec/etc/ossec.conf"
    
    disable_pf
    echo "Packet filter disabled."
    
    # Construct rules content
    local rules_content="block all\npass in inet proto tcp from $ip to any port $port\npass out inet proto tcp from any to $ip port $port"
    
    local rules_file="/tmp/pf.rules"
    echo -e "$rules_content" > "$rules_file"
    
    # Read contents of pf.conf
    local pf_conf_content
    pf_conf_content=$(<"/etc/pf.conf")
    
    # Remove rules content from pf.conf content
    pf_conf_content=$(echo "$pf_conf_content" | sed "/$rules_content/d")
    
    # Write the updated contents back to pf.conf
    echo -e "$pf_conf_content" > "/etc/pf.conf"
    
    # Reload pf.conf
    /sbin/pfctl -f /etc/pf.conf
    
    enable_pf
    echo "Packet filter enabled."
    
    echo "Packet filter configured with rules based on the IP address $ip and port $port from the file /Library/Ossec/etc/ossec.conf."
}

# Call the main function
main
