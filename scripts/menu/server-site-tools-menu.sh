#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Server Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("Backup All Domains" "Clear All Caches" "Dispay Server Info" "Fix Permissions" "Optimize All Images" "Testssl.sh" "Exit Server Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Backup All Domains")
          echo "Backing up all domains..."
          /usr/local/bin/enginescript/scripts/functions/alias/alias-backup.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Clear All Caches")
          echo "Clearing all caches..."
          /usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
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
        "Fix Permissions")
          echo "Fixing permissions for all domains..."
          /usr/local/bin/enginescript/scripts/functions/cron/permissions.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Optimize All Images")
          echo "Optimizing images in /uploads directory for all domains..."
          /usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Testssl.sh")
          /usr/local/bin/enginescript/scripts/functions/server-tools/testssl.sh
          echo ""
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Exit Server Tools")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
