#!/bin/bash

# DESC: Simple Home Folder Backup Manager with TUI interface.
# Backs up selected folders/files in ~/ to individually compressed .tar.gz files.
# Each backup is stored in /media/nickh/Backup/Home-Backups/YYYY-MM-DD-HH-MM-SS/
# Backup selections, timestamps, and known items are saved as dotfiles in ~

BACKUP_DEST="/media/nickh/Backup/Home-Backups"
CONFIG_FILE="$HOME/.home-backup-config"
TIMESTAMP_FILE="$HOME/.home-backup-timestamps"
KNOWN_FILE="$HOME/.home-backup-known"
TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")

# Colour codes
YELLOW=$(tput setaf 3)
BRIGHT_YELLOW=$(tput setaf 3; tput bold)
DIM=$(tput dim)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
GREY=$(tput setaf 7)
DIM=$(tput dim)


# Ensure necessary files and folders exist
mkdir -p "$BACKUP_DEST"
touch "$CONFIG_FILE" "$TIMESTAMP_FILE"

if [[ ! -f "$KNOWN_FILE" ]]; then
  echo "${YELLOW}ℹ️ Creating $KNOWN_FILE to track seen files/folders.${RESET}"
  echo "${YELLOW}This file tracks which files/folders have already appeared in your home folder.${RESET}"
  touch "$KNOWN_FILE"
fi

# Load backup selections from config file
declare -A TO_BACKUP
while IFS="=" read -r key val; do
  TO_BACKUP["$key"]="$val"
done < "$CONFIG_FILE"

# Load last backup timestamps
declare -A LAST_BACKUP
while IFS="=" read -r key val; do
  LAST_BACKUP["$key"]="$val"
done < "$TIMESTAMP_FILE"

# Load previously seen items
declare -A KNOWN_ITEMS
while read -r line; do
  [[ -n "$line" ]] && KNOWN_ITEMS["$line"]=1
done < "$KNOWN_FILE"

# Get top-level files/folders in home directory
mapfile -t HOME_ITEMS < <(find "$HOME" -mindepth 1 -maxdepth 1 -printf "%f\n" | sort)

# Prepopulate sensible defaults if config is empty
if [[ ! -s "$CONFIG_FILE" ]]; then
  for item in "${HOME_ITEMS[@]}"; do
    case "$item" in
      Documents|Pictures|Desktop|Templates|Public|Scripts)
        TO_BACKUP["$item"]="true" ;;
      .config|.ssh|.gnupg|.local|.vscode|Code|.pki|.dotnet)
        TO_BACKUP["$item"]="true" ;;
      Videos|Music|Downloads)
        TO_BACKUP["$item"]="false" ;;
      .cache|snap|.gnome|.bashrc|.bash_logout|.bash_history|.profile|.pam_environment|.lesshst|.sudo_as_admin_successful|.home-backup-config|.home-backup-timestamps|.home-backup-known)
        TO_BACKUP["$item"]="false" ;;
      *) TO_BACKUP["$item"]="false" ;;
    esac
  done
fi

# ========== MAIN LOOP ==========
while true; do
  clear
  echo "     =================    🗃️  Home Backup Manager    ================="
  printf "\n %-3s │ %-30s %1s │ %-8s │ %-4s │ %-19s\n" "No." "Item" "!" "Size" "Bkup?" "Last Backup"
  printf " ────┼──────────────────────────────────┼──────────┼───────┼─────────────────────\n"

  TOTAL_BYTES=0

  for i in "${!HOME_ITEMS[@]}"; do
    item="${HOME_ITEMS[$i]}"
    path="$HOME/$item"

    # Skip missing files/folders
    [[ ! -e "$path" ]] && continue

    # Get size in MB
    size_bytes=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
    size_mb=$((size_bytes / 1024 / 1024))
    size_disp="${size_mb}MB"

    # Add to total if selected for backup
    [[ "${TO_BACKUP[$item]}" == "true" ]] && (( TOTAL_BYTES += size_bytes ))

    # Get backup toggle icon
    [[ "${TO_BACKUP[$item]}" == "true" ]] && status="✅" || status="❌"

    # Get last backup timestamp
    last="${LAST_BACKUP[$item]:---}"

    # Mark new items with a !
    marker=" "
    if [[ -z "${KNOWN_ITEMS[$item]}" ]]; then
      marker="!"
    fi

    # Highlight if item is new (not seen before) or grey if to be ignored
    if [[ -z "${KNOWN_ITEMS[$item]}" ]]; then
      printf "${BRIGHT_YELLOW} %-3s │ %-30s %1s │ %8s │  %-5s │ %-19s${RESET}\n" "$((i+1))" "$item" "$marker" "$size_disp" "$status" "$last" 
    elif [[ "${TO_BACKUP[$item]}" != "true" ]]; then
                printf "${DIM} %-3s │ %-30s %1s │ %8s │  %-5s │ %-19s${RESET}\n" "$((i+1))" "$item" "$marker" "$size_disp" "$status" "$last"
    else
                      printf " %-3s │ %-30s %1s │ %8s │  %-5s │ %-19s %1s\n" "$((i+1))" "$item" "$marker" "$size_disp" "$status" "$last"
    fi

  done

  total_size_hr=$(numfmt --to=iec-i --suffix=B <<< "$TOTAL_BYTES")
  printf "\n %38s     ${GREEN}%-10s${RESET}\n" "Total backup size:" "$total_size_hr"

  echo ""
  echo "Legend: ! = New item (not seen in previous backups)"

  echo ""
  echo "[T] Toggle item"
  echo "[B] Backup selected"
  echo "[R] Reinstate backup"
  echo "[Q] Quit"
  echo ""

  read -rp "Choose an action: " action

  case "$action" in
    [Tt])
      read -rp "Enter item number to toggle: " num
      index=$((num - 1))
      if [[ $index -ge 0 && $index -lt ${#HOME_ITEMS[@]} ]]; then
        item="${HOME_ITEMS[$index]}"
        [[ "${TO_BACKUP[$item]}" == "true" ]] && TO_BACKUP["$item"]="false" || TO_BACKUP["$item"]="true"
      else
        echo "❌ Invalid number."
        sleep 1
      fi
      ;;

    [Bb])
      TARGET_DIR="$BACKUP_DEST/Backup-$TIMESTAMP"
      mkdir -p "$TARGET_DIR"
      echo "📦 Backing up to: $TARGET_DIR"
      echo ""

      for item in "${!TO_BACKUP[@]}"; do
        [[ "${TO_BACKUP[$item]}" != "true" ]] && continue
        src="$HOME/$item"
        [[ ! -e "$src" ]] && echo "⚠️  Skipping $item (not found)" && continue

        echo "📁 Compressing: $item"
        tar -czf "$TARGET_DIR/${item}.tar.gz" -C "$HOME" "$item"
        LAST_BACKUP["$item"]="$TIMESTAMP"
      done

      # Update known items
      printf "%s\n" "${HOME_ITEMS[@]}" > "$KNOWN_FILE"

      echo ""
      echo "✅ Backup complete!"
      sleep 2
      ;;

    [Rr])
      echo ""
      echo "📂 Available reinstatements in $BACKUP_DEST:"
      mapfile -t BACKUP_FOLDERS < <(find "$BACKUP_DEST" -maxdepth 1 -type d -name "Backup-*")
      if [[ ${#BACKUP_FOLDERS[@]} -eq 0 ]]; then
        echo "No backups found."
        sleep 2
        continue
      fi

      for i in "${!BACKUP_FOLDERS[@]}"; do
        name=$(basename "${BACKUP_FOLDERS[$i]}")
        printf " %-3s │ %s\n" "$((i+1))" "$name"
      done

      read -rp "Choose number to reinstate: " sel
      index=$((sel - 1))

      if [[ $index -ge 0 && $index -lt ${#BACKUP_FOLDERS[@]} ]]; then
        selected="${BACKUP_FOLDERS[$index]}"
        reinstated_dir="$HOME/Reinstated-Backup-$(basename "$selected")"
        mkdir -p "$reinstated_dir"

        echo ""
        echo "🧩 Reinstating to $reinstated_dir"
        for archive in "$selected"/*.tar.gz; do
          echo "🔄 Extracting $(basename "$archive")"
          tar -xzf "$archive" -C "$reinstated_dir"
        done

        echo "✅ Reinstatement complete."
        sleep 2
      else
        echo "❌ Invalid choice."
        sleep 1
      fi
      ;;

    [Qq])
      # Save config and timestamps
      > "$CONFIG_FILE"
      for key in "${!TO_BACKUP[@]}"; do
        echo "$key=${TO_BACKUP[$key]}" >> "$CONFIG_FILE"
      done

      > "$TIMESTAMP_FILE"
      for key in "${!LAST_BACKUP[@]}"; do
        echo "$key=${LAST_BACKUP[$key]}" >> "$TIMESTAMP_FILE"
      done

      echo "👋 Goodbye!"
      exit 0
      ;;

    *)
      echo "❌ Invalid input."
      sleep 1
      ;;
  esac
done
