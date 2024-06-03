#!/bin/bash

# Disable the specified kernel extensions
sudo kextunload -b com.apple.iokit.IOFireWireSerialBusProtocolTransport
sudo kextunload -b com.apple.iokit.IOUSBMassStorageDriver

# Block USB ports
sudo sh -c 'echo "kext-dev-mode=1" > /etc/rc.conf'
sudo sh -c 'echo "debug=0x144" >> /etc/rc.conf'

echo "Kernel extensions disabled and USB ports blocked successfully."

