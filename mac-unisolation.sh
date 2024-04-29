#!/bin/bash

# Disable PF
sudo pfctl -d

# Restore default PF rules (assuming default is less restrictive)
sudo pfctl -f /etc/pf.conf

# Unload and remove the Launch Agent
sudo launchctl unload /Library/LaunchDaemons/com.user.pfisolation.plist
sudo rm /Library/LaunchDaemons/com.user.pfisolation.plist
