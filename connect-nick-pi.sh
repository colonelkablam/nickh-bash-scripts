#!/bin/bash
# connect_nickpi.sh — choose Tailscale or local SSH, show routing & run ssh -v

set -euo pipefail

# === Config ===
TS_HOST="nick-pi"          # Tailscale MagicDNS name
LOCAL_HOST="nick-pi.local" # mDNS .local name (fallback)
USER="nickh"               # your Pi username

# Resolve-and-ssh over a given hostname
do_connect() {
  local name=$1
  echo "► Resolving $name ..."
  IP=$(getent ahosts "$name" | awk '{print $1; exit}') || {
    echo "✖ Could not auto-resolve $name"
    read -p "Enter IP address manually: " IP
  }
  echo "✔ $name → $IP"
  echo
  echo "► Checking route to $IP ..."
  ip route get "$IP"
  echo
  echo "► Starting SSH ..."
  ssh "${USER}@${name}"
}

main() {
  echo "How would you like to connect to your Pi?"
  echo "  1) Tailscale"
  echo "  2) Local network (mDNS/IP)"
  read -p "Choose [1/2]: " choice

  case $choice in
    1)
      # Check if Tailscale is running
      if ! tailscale status >/dev/null 2>&1; then
        read -p "Tailscale isn’t up. Run 'sudo tailscale up'? [Y/n]: " yn
        if [[ $yn =~ ^[Yy] ]] || [[ -z $yn ]]; then
          sudo tailscale up
        else
          echo "Aborting Tailscale connection." >&2
          exit 1
        fi
      fi
      do_connect "$TS_HOST"
      ;;
    2)
      do_connect "$LOCAL_HOST"
      ;;
    *)
      echo "Invalid choice." >&2
      exit 1
      ;;
  esac
}

main
