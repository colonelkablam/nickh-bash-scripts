#!/bin/bash

# A simple TLP management script
# Nick's quick-access tool for controlling laptop power tuning

# Line below is the description that can be printed out
# DESC: Toggles TLP power management service


while true; do
  echo ""
  echo "🔋 TLP Manager"
  echo "=============="
  echo "1) Start TLP now"
  echo "2) Stop TLP now"
  echo "3) Enable TLP at boot"
  echo "4) Disable TLP at boot"
  echo "5) TLP status (is it running?)"
  echo "6) Quit"
  echo ""
  read -rp "Select an option [1-6]: " choice

  case "$choice" in
    1)
      echo "➡ Starting TLP..."
      sudo systemctl start tlp
      ;;
    2)
      echo "⏹ Stopping TLP..."
      sudo systemctl stop tlp
      ;;
    3)
      echo "🔁 Enabling TLP to run at startup..."
      sudo systemctl enable tlp
      ;;
    4)
      echo "🛑 Disabling TLP from running at startup..."
      sudo systemctl disable tlp
      ;;
    5)
      echo "📊 TLP status:"
      sudo tlp-stat -s
      ;;
    6)
      echo "👋 Exiting."
      exit 0
      ;;
    *)
      echo "❌ Invalid option. Please enter a number between 1 and 6."
      ;;
  esac
done
