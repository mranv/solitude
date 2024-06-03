#!/bin/bash

# Rule to block all USB Ports
no_usb="# this rule does not allow any new usb devices, use script to disable\nACTION==\"add\", DRIVERS==\"usb\",  ATTR{authorized}=\"0\"\n"
fname="/etc/udev/rules.d/11-to_rule_all.rules"
wait=20 # wait 20 seconds for new usb device

sig_handler() {
  if [ "$1" == "SIGUSR1" ]; then
    echo "received SIGUSR1"
  elif [ "$1" == "SIGTERM" ]; then
    echo "received SIGSTERM"
  elif [ "$1" == "SIGINT" ]; then
    echo "received SIGINT"
  fi
  make_file
}

make_file() {
  echo "Block all new USB rule added"
  echo -e "$no_usb" | sudo tee "$fname" >/dev/null
}

do_setuid() {
  if [ "$1" == "set" ]; then
    sudo -k
    sudo chmod u+s "$0"
    echo "Effective UID changed"
  elif [ "$1" == "unset" ]; then
    sudo chmod u-s "$0"
    echo "Effective UID reset"
  fi
}

echo "1. Block all USB Ports"
echo "2. Temporarily Unblock all USB Ports"
echo "3. Permanently Unblock all USB Ports"
read -p "Enter your choice: " choice

case $choice in
  3)
    do_setuid set
    if [ -f "$fname" ]; then
      echo -e "$allow_rule" | sudo tee "$fname" >/dev/null
      sudo rm -rf "$fname"
      echo "Unblocked USB Ports."
    else
      echo "USB Ports are not blocked."
    fi
    do_setuid unset
    ;;
  2)
    do_setuid set
    if [ -f "$fname" ]; then
      echo -e "$allow_rule" | sudo tee "$fname" >/dev/null
      sudo rm -rf "$fname"
      echo "USB Ports Temporarily Unblocked for 20 seconds."
      sleep $wait
      echo "Blocking again."
      trap "sig_handler" SIGTERM SIGINT SIGUSR1
      make_file
    else
      echo "USB Ports are not blocked."
    fi
    do_setuid unset
    ;;
  1)
    trap "sig_handler" SIGTERM SIGINT SIGUSR1
    make_file
    ;;
  *)
    echo "Run program again with correct input."
    ;;
esac

exit 0
