#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Server Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("Dispay Server Info" "Update EngineScript" "View/Edit EngineScript Install Configuration File" "View/Edit EngineScript Variables File" "Exit EngineScript Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Dispay Server Info")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
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
        *) echo invalid option;;
      esac
    done
  done
