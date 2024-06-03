#!/bin/bash

# Temporarily Unblock USB Ports
fname="/etc/udev/rules.d/11-to_rule_all.rules"
wait=20 # wait 20 seconds for new usb device

allow_rule="#tmp allows all USB devices\nACTION==\"add\", DRIVERS==\"usb\"\n"

temp_unblock_usb() {
  if [ -f "$fname" ]; then
    echo -e "$allow_rule" | sudo tee "$fname" >/dev/null
    sudo rm -rf "$fname"
    echo "USB Ports Temporarily Unblocked for $wait seconds."
    sleep $wait
    echo "Blocking USB Ports again."
    block_usb
  else
    echo "USB Ports are not blocked."
  fi
}

block_usb() {
  no_usb="# this rule does not allow any new usb devices, use script to disable\nACTION==\"add\", DRIVERS==\"usb\", ATTR{authorized}=\"0\"\n"
  echo -e "$no_usb" | sudo tee "$fname" >/dev/null
  echo "USB Ports have been blocked."
}

temp_unblock_usb

exit 0
