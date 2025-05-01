#!/bin/bash

# DESC: Lists all the nickh-created executable scripts available in ~/.local/bin.

wrap() {
  fold -s -w 40
}

SCRIPTS=()

show_menu() {
  clear
  echo ""
  printf " %-4s | %-20s | %-40s\n" "No." "Script Name" "Description"
  printf "%s\n" "--------------------------------------------------------------------------------"

  i=1
  for file in ~/.local/bin/*; do
    if [[ -x "$file" && -f "$file" ]]; then
      scriptname=$(basename "$file")
      desc=$(grep -m1 '^# DESC:' "$file" | sed 's/^# DESC: *//')

      desc=${desc:-"No description provided."}
      SCRIPTS+=("$scriptname")

      # Wrap description
      mapfile -t wrapped_desc < <(echo "$desc" | wrap)

      # Print first line
      printf " %-4s | %-20s | %-40s\n" "$i" "$scriptname" "${wrapped_desc[0]}"

      # Additional wrapped lines
      for ((j=1; j<${#wrapped_desc[@]}; j++)); do
        printf " %-4s | %-20s | %-40s\n" " " " " "${wrapped_desc[$j]}"
      done

      printf "%s\n" "--------------------------------------------------------------------------------"
      ((i++))
    fi
  done
}

# --- MAIN LOOP ---
while true; do
  show_menu
  echo ""
  read -rp "📜 Enter a number to run a script, or 'q' to quit: " choice

  if [[ "$choice" =~ ^[Qq]$ ]]; then
    echo "👋 Exiting launcher."
    exit 0
  elif [[ "$choice" =~ ^[0-9]+$ ]]; then
    index=$((choice-1))
    if [[ $index -ge 0 && $index -lt ${#SCRIPTS[@]} ]]; then
      echo ""
      echo "🚀 Launching ${SCRIPTS[$index]}..."
      sleep 1
      ~/.local/bin/"${SCRIPTS[$index]}"

      echo ""
      read -rp "↩️  Press Enter to return to menu, or 'q' to quit: " postrun
      if [[ "$postrun" =~ ^[Qq]$ ]]; then
        echo "👋 Exiting launcher."
        exit 0
      fi
    else
      echo "❌ Invalid number: $choice"
      sleep 1
    fi
  else
    echo "❌ Invalid input."
    sleep 1
  fi
done
