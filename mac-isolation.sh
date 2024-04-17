#!/bin/bash

# Function to read IP address and port from file
readIPAndPortFromFile() {
    local filePath="$1"
    content=$(<"$filePath")

    ip=$(echo "$content" | sed -n 's/.*<address>\(.*\)<\/address>.*/\1/p' | tr -d '[:space:]')
    port=$(echo "$content" | sed -n 's/.*<port>\(.*\)<\/port>.*/\1/p' | tr -d '[:space:]')

    if [ -z "$ip" ] || [ -z "$port" ]; then
        echo "IP address or port not found in file at path: $filePath"
        return 1
    fi

    echo "$ip $port"
}

# Function to update configuration file with timestamp
updateConfigFileWithTimestamp() {
    local filePath="$1"
    local timestamp="$2"
    
    if ! content=$(<"$filePath"); then
        echo "Failed to read file at path: $filePath"
        return 1
    fi
    
    insertionPoint=$(echo "$content" | grep -b -o "</ossec_config>" | cut -d':' -f1)
    
    if [ -z "$insertionPoint" ]; then
        echo "Insertion point not found in file at path: $filePath"
        return 1
    fi
    
    newContent="\n<labels>\n  <label key=\"isolated.time\">$timestamp</label>\n</labels>\n"
    sed -i '' "${insertionPoint}i\\$newContent" "$filePath"
    
    echo "File updated with timestamp at path: $filePath"
}

# Function to disable pf firewall
disablePF() {
    /sbin/pfctl -d
    echo "Packet filter disabled."
}

# Function to verify rules
verifyRules() {
    /sbin/pfctl -sr
}

# Function to enable pf firewall
enablePF() {
    /sbin/pfctl -e
    echo "Packet filter enabled."
}

# Function to make pf rules persistent
makePFPersistent() {
    rulesFile="/etc/pf.conf"
    rulesAnchorFile="/etc/pf.anchors/custom_rules.pf"

    # Save current pf rules to a file
    /sbin/pfctl -s rules > "$rulesAnchorFile"

    # Modify pf.conf to load the anchor file at boot time
    sed -i '' '/^anchor/pf\.osx\//a\
    anchor "custom_rules"' "$rulesFile"
    
    echo "PF rules made persistent."
}

# Main function
main() {
    ipAndPort=$(readIPAndPortFromFile "/Library/Ossec/etc/ossec.conf")
    if [ $? -ne 0 ]; then
        return
    fi
    
    ip=$(echo "$ipAndPort" | cut -d' ' -f1)
    port=$(echo "$ipAndPort" | cut -d' ' -f2)
    
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
    updateConfigFileWithTimestamp "/Library/Ossec/etc/ossec.conf" "$timestamp"
    
    disablePF
    echo "Packet filter disabled."
    
    rulesContent="block all\npass in inet proto tcp from $ip to any port $port\npass out inet proto tcp from any to $ip port $port"
    rulesFilePath="/etc/pf.anchors/custom_rules.pf"
    echo -e "$rulesContent" > "$rulesFilePath"
    
    verifyRules
    
    /sbin/pfctl -f /etc/pf.conf
    
    enablePF
    echo "Packet filter enabled."
    
    makePFPersistent
    
    echo "Packet filter configured with rules based on the IP address $ip and port $port from the file /Library/Ossec/etc/ossec.conf."
}

# Call the main function
main
