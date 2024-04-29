#!/bin/bash

# Define the path for the isolated pf configuration
ISOLATED_PF_CONF="/etc/pf.conf.isolated"

# Create the pf rules file for isolation
echo "block in all
block out all
pass in on lo0
pass out on lo0" | sudo tee $ISOLATED_PF_CONF

# Load the isolation rules
sudo pfctl -f $ISOLATED_PF_CONF

# Enable PF
sudo pfctl -e

# Create a Launch Agent to persist the settings
sudo tee /Library/LaunchDaemons/com.user.pfisolation.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.pfisolation</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>pfctl -f $ISOLATED_PF_CONF; pfctl -e</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

# Load the Launch Agent
sudo launchctl load /Library/LaunchDaemons/com.user.pfisolation.plist
