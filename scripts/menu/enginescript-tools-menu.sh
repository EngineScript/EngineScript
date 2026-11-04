#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Wait for a key before the menu redraws
pause() {
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
  echo ""
  echo ""
}

# Which install steps are done, from /etc/enginescript/install-state.conf; es.install runs the
# steps that are not done yet
show_install_state() {
  local state_file=/etc/enginescript/install-state.conf key value done=0 total=0 i=0
  local -a pending=()
  echo ""
  if [[ ! -r "${state_file}" ]]; then
    echo "There is no install state yet (${state_file}): EngineScript has not been installed."
    return 1
  fi
  echo "Install steps (done = 1):"
  while IFS='=' read -r key value; do
    total=$((total + 1))
    if [[ "${value}" == "1" ]]; then
      done=$((done + 1))
    else
      pending+=("${key}")
    fi
    printf '  %-22s %s' "${key}" "${value}"
    i=$((i + 1))
    (( i % 3 == 0 )) && echo ""
  done < <(grep -E '^[A-Z0-9_]+=[01]$' "${state_file}")
  (( i % 3 != 0 )) && echo ""
  echo ""
  echo "${done} of ${total} steps are done."
  if [[ "${#pending[@]}" -gt 0 ]]; then
    echo "Not done yet: ${pending[*]}"
    echo "es.install runs the steps that are not done."
  fi
}

# The newest dated section of EngineScript's changelog (the version on this server)
show_latest_changes() {
  local changelog=/usr/local/bin/enginescript/CHANGELOG.md
  if [[ ! -r "${changelog}" ]]; then
    echo "There is no changelog at ${changelog}."
    return 1
  fi
  awk '/^## / { n++ } n == 1' "${changelog}" | less -FX
}

# Main Menu
while true
  do
    clear
    echo -e "EngineScript Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Display Server Info"
      "Run EngineScript Debug Report"
      "Show Install State"
      "Show Latest Changes (Changelog)"
      "Update EngineScript"
      "View/Edit EngineScript Install Configuration File"
      "View/Edit EngineScript Variables File"
      "Exit EngineScript Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Display Server Info")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Run EngineScript Debug Report")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-debug.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Show Install State")
          show_install_state
          pause
          break
          ;;
        "Show Latest Changes (Changelog)")
          show_latest_changes
          pause
          break
          ;;
        "Update EngineScript")
          /usr/local/bin/enginescript/scripts/update/enginescript-update.sh
          break
          ;;
        "View/Edit EngineScript Install Configuration File")
          nano /home/EngineScript/enginescript-install-options.txt
          break
          ;;
        "View/Edit EngineScript Variables File")
          nano /usr/local/bin/enginescript/enginescript-variables.txt
          break
          ;;
        "Exit EngineScript Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
