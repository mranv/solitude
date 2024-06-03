#!/bin/bash

# Block USB Ports
no_usb="# this rule does not allow any new usb devices, use script to disable\nACTION==\"add\", DRIVERS==\"usb\", ATTR{authorized}=\"0\"\n"
fname="/etc/udev/rules.d/11-to_rule_all.rules"

block_usb() {
  echo -e "$no_usb" | sudo tee "$fname" >/dev/null
  echo "USB Ports have been blocked."
}

block_usb

exit 0
