#!/bin/bash

# DESC: Script Manager to activate, link, rename, delete, and back up Bash scripts.

SCRIPTS_DIR="$HOME/Scripts"                    # Main script directory
LOCAL_BIN="$HOME/.local/bin"                   # Where symlinks will be placed
BACKUP_DIR="$SCRIPTS_DIR/Nick-Scripts-Backup"  # Backup folder path

# Colour codes for nicer output
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

mkdir -p "$BACKUP_DIR"  # Ensure backup directory exists

# Backup a script to the backup folder (chmod -x to keep it safe)
backup_script() {
  src="$1"
  base_name=$(basename "$src")
  backup_name="${base_name%.sh}-backup.sh"
  dest="$BACKUP_DIR/$backup_name"

  echo "Running: cp \"$src\" \"$dest\""
  cp "$src" "$dest"
  echo "Running: chmod -x \"$dest\""
  chmod -x "$dest"
  echo "${GREEN}✅ Backup created at: $dest${RESET}"
}

# Remove an executable symlink from ~/.local/bin
delete_link() {
  echo ""
  link="$1"
  real_target=$(readlink -f "$link")

  echo "${RED}⚠️ About to delete symlink: $link${RESET}"
  read -rp "Are you sure? (y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Running: rm \"$link\""
    rm "$link"
    echo "${GREEN}✅ Symlink deleted.${RESET}"
  else
    echo "❎ Cancelled deletion."
  fi
}

# List all backup scripts, sorted, with modification times
list_backups() {
  echo ""
  echo "📦 Backed up scripts in $BACKUP_DIR:"
  echo ""

  mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.sh" | sort)

  if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "${YELLOW}No backups found.${RESET}"
  else
    # Print nicely formatted backup table
    printf " %-4s | %-30s | %20s\n" "No." "Backup Name" "Last Modified"
    printf " ------------------------------------------------------------\n"

    for i in "${!BACKUPS[@]}"; do
      name=$(basename "${BACKUPS[$i]}")
      mtime=$(date -r "${BACKUPS[$i]}" "+%Y-%m-%d %H:%M:%S")
      printf " %-4s | %-30s | %20s\n" "$((i+1))" "$name" "$mtime"
    done
  fi

  echo ""
}

# --- Main Menu Loop ---
while true; do
  clear  # Refresh screen
  echo ""
  echo "==================== ${YELLOW}Nick's Script Manager${RESET} ===================="
  echo ""

  # List all .sh files in ~/Scripts
  mapfile -t SH_SCRIPTS < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh")

  echo "🔧 All .sh scripts in $SCRIPTS_DIR:"
  echo ""

  if [ ${#SH_SCRIPTS[@]} -eq 0 ]; then
    echo "${YELLOW}No .sh scripts found.${RESET}"
  else
    # Show scripts and whether they are executable or not
    for i in "${!SH_SCRIPTS[@]}"; do
      script_path="${SH_SCRIPTS[$i]}"
      script_name="$(basename "$script_path")"

      if [[ -x "$script_path" ]]; then
        status="⚙️"  # Executable icon
      else
        status="📄"  # Plain file icon
      fi

      printf " %-2s  %s  %s\n" "$((i+1))" "$script_name" "$status"
    done
  fi

  echo ""
  echo "----------------------------------------------------------"
  echo ""

  # Show any existing symlinks in ~/.local/bin
  mapfile -t EXECUTABLE_LINKS < <(find "$LOCAL_BIN" -maxdepth 1 -type l)

  echo "⚙️  Executable links in $LOCAL_BIN:"
  echo ""

  if [ ${#EXECUTABLE_LINKS[@]} -eq 0 ]; then
    echo "${YELLOW}No executable links found.${RESET}"
  else
    for i in "${!EXECUTABLE_LINKS[@]}"; do
      printf " %-2s  %s\n" "$((i+1))" "$(basename "${EXECUTABLE_LINKS[$i]}")"
    done
  fi

  echo ""
  echo "=========================================================="
  echo ""
  echo "[1] Manage Scripts"
  echo "[2] Manage Executable Links"
  echo "[3] View and Manage Backups"
  echo "[Q] Quit"
  echo ""
  read -rp "Select an option: " menu_choice

  # Menu logic starts here...

  if [[ "$menu_choice" =~ ^[Qq]$ ]]; then
    # Quit the script manager
    echo "${YELLOW}👋 Exiting Script Manager.${RESET}"
    exit 0


  elif [[ "$menu_choice" == "1" ]]; then

  # --- Manage scripts in ~/Scripts ---

    clear
    echo ""
    echo "📂 Scripts in $SCRIPTS_DIR:"
    echo ""

    # Re-list all .sh scripts
    mapfile -t ALL_SCRIPTS < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh")

    if [ ${#ALL_SCRIPTS[@]} -eq 0 ]; then
      echo "${YELLOW}No .sh scripts found in $SCRIPTS_DIR.${RESET}"
      read -rp "↩️ Press Enter to return..."
      continue
    fi

    # Display numbered list with exec status
    printf " No. | %-30s | Executable?\n" "Script Name"
    printf " --------------------------------------------------\n"

    for i in "${!ALL_SCRIPTS[@]}"; do
      name=$(basename "${ALL_SCRIPTS[$i]}")
      [[ -x "${ALL_SCRIPTS[$i]}" ]] && exec_status="✅" || exec_status="❌"
      printf " %-3s | %-30s |     %s\n" "$((i+1))" "$name" "$exec_status"
    done

    # Prompt for script actions
    echo ""
    echo "Actions:"
    echo "[X] Toggle Executable   [L] Link to ~/.local/bin (only if exec)"
    echo "[R] Rename              [C] Copy"
    echo "[D] Delete              [B] Backup"
    echo "[Q] Back to Main Menu"
    echo ""

    read -rp "Choose script number [1-n] or [R]eturn: " choice

    if [[ "$choice" =~ ^[Rr]$ ]]; then continue; fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      index=$((choice - 1))
      if [[ $index -ge 0 && $index -lt ${#ALL_SCRIPTS[@]} ]]; then
        selected="${ALL_SCRIPTS[$index]}"
        base_name=$(basename "$selected")
        [[ -x "$selected" ]] && is_exec=true || is_exec=false

        read -rp "Choose action [X/L/R/C/D/B/Q]: " action
        case "$action" in
          [Xx])
            # Toggle executable status
            if $is_exec; then
              echo "Running: chmod -x \"$selected\""
              chmod -x "$selected"
              echo "${YELLOW}Made $base_name non-executable.${RESET}"

              # Remove symlink if script is unlinked
              link_path="$LOCAL_BIN/${base_name%.sh}"
              if [ -L "$link_path" ]; then
                echo "Removing link: $link_path"
                rm "$link_path"
                echo "${YELLOW}🧹 Removed symlink for non-executable script.${RESET}"
              fi
            else
              echo "Running: chmod +x \"$selected\""
              chmod +x "$selected"
              echo "${GREEN}Made $base_name executable.${RESET}"
            fi
            ;;
          [Ll])
            # Create symlink if script is executable
            if $is_exec; then
              link_name="${base_name%.sh}"
              if [ -e "$LOCAL_BIN/$link_name" ]; then
                echo "${RED}⚠️ Link already exists: $LOCAL_BIN/$link_name${RESET}"
              else
                echo "Running: ln -s \"$selected\" \"$LOCAL_BIN/$link_name\""
                ln -s "$selected" "$LOCAL_BIN/$link_name"
                echo "${GREEN}✅ Linked as $link_name${RESET}"
              fi
            else
              echo "${RED}❌ Cannot link non-executable script.${RESET}"
            fi
            ;;
          [Rr])
            # Rename script file
            read -rp "New name (without .sh): " new_name
            new_path="$SCRIPTS_DIR/$new_name.sh"
            if [ -e "$new_path" ]; then
              echo "${RED}❌ File already exists: $new_path${RESET}"
            else
              echo "Running: mv \"$selected\" \"$new_path\""
              mv "$selected" "$new_path"
              echo "${GREEN}✅ Renamed to $new_name.sh${RESET}"
            fi
            ;;
          [Cc])
            # Copy script to new name
            read -rp "Name for copy (without .sh): " copy_name
            copy_path="$SCRIPTS_DIR/$copy_name.sh"
            if [ -e "$copy_path" ]; then
              echo "${RED}❌ File already exists: $copy_path${RESET}"
            else
              echo "Running: cp \"$selected\" \"$copy_path\""
              cp "$selected" "$copy_path"
              echo "${GREEN}✅ Copied to $copy_name.sh${RESET}"
            fi
            ;;
          [Dd])
            # Confirm and delete with backup
            echo "${RED}⚠️ About to delete $base_name from $SCRIPTS_DIR${RESET}"
            read -rp "Are you sure you want to delete this script? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
              backup_script "$selected"

              # Remove any linked symlink
              link_name="${base_name%.sh}"
              link_path="$LOCAL_BIN/$link_name"
              if [ -L "$link_path" ]; then
                echo "Removing link: $link_path (script being deleted)"
                rm "$link_path"
                echo "${YELLOW}🧹 Removed associated symlink.${RESET}"
              fi

              echo "Running: rm \"$selected\""
              rm "$selected"
              echo "${GREEN}✅ Deleted $base_name${RESET}"
            else
              echo "❎ Cancelled deletion."
            fi
            ;;
          [Bb])
            # Backup the selected script
            echo "📦 Backing up script to $BACKUP_DIR:"
            backup_script "$selected"
            ;;
          [Qq]) ;; # No action, back to main
          *)
            echo "${RED}❌ Invalid action.${RESET}"
            ;;
        esac
      else
        echo "${RED}❌ Invalid script number.${RESET}"
      fi
    else
      echo "${RED}❌ Invalid input.${RESET}"
    fi

    read -rp "↩️ Press Enter to return..."


  elif [[ "$menu_choice" == "2" ]]; then

  # --- Manage Executable Links ---

    clear
    echo ""
    echo "⚙️  Executable links in $LOCAL_BIN:"
    echo ""

    # Get all symlinks from ~/.local/bin
    mapfile -t EXECUTABLE_LINKS < <(find "$LOCAL_BIN" -maxdepth 1 -type l)

    # Handle no links case
    if [ ${#EXECUTABLE_LINKS[@]} -eq 0 ]; then
      echo "${YELLOW}No executable links found.${RESET}"
      read -rp "↩️ Press Enter to return..."
      continue
    fi

    # Display list of symlinks
    for i in "${!EXECUTABLE_LINKS[@]}"; do
      printf " %-2s |  %s\n" "$((i+1))" "$(basename "${EXECUTABLE_LINKS[$i]}")"
    done

    echo ""
    # Prompt user for action
    read -rp "Choose a link number [1-n] to delete or [R]eturn: " choice

    if [[ "$choice" =~ ^[Rr]$ ]]; then
      continue  # Back to main menu
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
      index=$((choice - 1))
      if [[ $index -ge 0 && $index -lt ${#EXECUTABLE_LINKS[@]} ]]; then
        delete_link "${EXECUTABLE_LINKS[$index]}"  # Safe delete with prompt
        read -rp "↩️ Press Enter to return to the menu..."
      else
        echo "${RED}❌ Invalid link number.${RESET}"
        sleep 1
      fi
    else
      echo "${RED}❌ Invalid input.${RESET}"
      sleep 1
    fi

  elif [[ "$menu_choice" == "3" ]]; then

  # --- Manage Backups ---

    clear
    echo ""
    echo "📦 ${YELLOW}Backups in $BACKUP_DIR${RESET}"

    # Grab all backup .sh files
    mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.sh")

    list_backups  # Display table of backups with date/time

    echo "Actions:"
    echo "[B] Backup all scripts in $SCRIPTS_DIR"
    echo "[D] Delete a backup"
    echo "[I] reInstate a backup"
    echo "[R] Return to Main Menu"
    echo ""

    read -rp "Choose an option: " backup_choice

    case "$backup_choice" in

      [Bb])
        # Backup all .sh scripts in Scripts folder
        echo ""
        echo "${YELLOW}📦 Backing up all .sh scripts in $SCRIPTS_DIR...${RESET}"
        mapfile -t ALL_TO_BACKUP < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh")
        for script in "${ALL_TO_BACKUP[@]}"; do
          backup_script "$script"
        done
        read -rp "✅ All scripts backed up. ↩️ Press Enter to return..."
        ;;

      [Dd])
        # Delete a single backup
        if [ ${#BACKUPS[@]} -eq 0 ]; then
          echo "${YELLOW}Nothing to delete.${RESET}"
          read -rp "↩️ Press Enter to return..."
          continue
        fi

        echo ""
        read -rp "Enter backup number to delete or [R]eturn: " del_choice

        if [[ "$del_choice" =~ ^[Rr]$ ]]; then
          continue
        elif [[ "$del_choice" =~ ^[0-9]+$ ]]; then
          index=$((del_choice - 1))
          if [[ $index -ge 0 && $index -lt ${#BACKUPS[@]} ]]; then
            target="${BACKUPS[$index]}"
            echo "${RED}⚠️ Confirm deletion of $(basename "$target")${RESET}"
            read -rp "Are you sure? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
              echo "Running: rm \"$target\""
              rm "$target"
              echo "${GREEN}✅ Deleted backup $(basename "$target")${RESET}"
            else
              echo "❎ Cancelled deletion."
            fi
          else
            echo "${RED}❌ Invalid backup number.${RESET}"
          fi
        else
          echo "${RED}❌ Invalid input.${RESET}"
        fi
        read -rp "↩️ Press Enter to return..."
        ;;

      [Ii])
        # Reinstate a backup into ~/Scripts
        if [ ${#BACKUPS[@]} -eq 0 ]; then
          echo "${YELLOW}Nothing to reinstate.${RESET}"
          read -rp "↩️ Press Enter to return..."
          continue
        fi

        echo ""
        read -rp "Enter backup number to reinstate or [R]eturn: " rein_choice
        if [[ "$rein_choice" =~ ^[Rr]$ ]]; then
          continue
        elif [[ "$rein_choice" =~ ^[0-9]+$ ]]; then
          index=$((rein_choice - 1))
          if [[ $index -ge 0 && $index -lt ${#BACKUPS[@]} ]]; then
            src="${BACKUPS[$index]}"
            filename=$(basename "$src")

            # Create reinstated filename
            name_no_ext="${filename%.sh}"         # Remove .sh
            base_name="${name_no_ext%-backup}"    # Remove -backup suffix
            reinstated_name="${base_name}-reinstated.sh"
            dest="$SCRIPTS_DIR/$reinstated_name"

            # If file already exists, confirm overwrite
            if [[ -e "$dest" ]]; then
              echo "${RED}❌ File already exists: $reinstated_name${RESET}"
              read -rp "Overwrite? (y/n): " confirm
              if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "❎ Cancelled reinstating."
                read -rp "↩️ Press Enter to return..."
                continue
              fi
            fi

            echo "Running: cp \"$src\" \"$dest\""
            cp "$src" "$dest"
            echo "${GREEN}✅ Reinstated as $reinstated_name${RESET}"
          else
            echo "${RED}❌ Invalid backup number.${RESET}"
          fi
        else
          echo "${RED}❌ Invalid input.${RESET}"
        fi
        read -rp "↩️ Press Enter to return..."
        ;;

      [Rr])
        continue  # Return to main menu
        ;;

      *)
        echo "${RED}❌ Invalid choice.${RESET}"
        sleep 1
        ;;
    esac

  else
    echo "${RED}❌ Invalid menu choice.${RESET}"
    sleep 1
  fi
done
