#!/bin/bash

# Permanently Unblock USB Ports
fname="/etc/udev/rules.d/11-to_rule_all.rules"

allow_rule="#tmp allows all USB devices\nACTION==\"add\", DRIVERS==\"usb\"\n"

perm_unblock_usb() {
  if [ -f "$fname" ]; then
    echo -e "$allow_rule" | sudo tee "$fname" >/dev/null
    sudo rm -rf "$fname"
    echo "USB Ports have been permanently unblocked."
  else
    echo "USB Ports are not blocked."
  fi
}

perm_unblock_usb

exit 0
