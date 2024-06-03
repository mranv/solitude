#!/bin/bash

# Enable the specified kernel extensions
sudo kextload -b com.apple.iokit.IOFireWireSerialBusProtocolTransport
sudo kextload -b com.apple.iokit.IOUSBMassStorageDriver

# Unblock USB ports
sudo sed -i '' '/kext-dev-mode=1/d' /etc/rc.conf
sudo sed -i '' '/debug=0x144/d' /etc/rc.conf

echo "Kernel extensions enabled and USB ports unblocked successfully."

