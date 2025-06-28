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



#----------------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Site Maintenance Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("Backup (All Domains)" "Clear Caches (All Domains)" "Fix Permissions (All Domains)" "Optimize Images (All Domains)" "SSL Capabilities Test (Single Domain)" "Exit Server Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Backup (All Domains)")
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
        "Clear Caches (All Domains)")
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
        "Fix Permissions (All Domains)")
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
        "Optimize Images (All Domains)")
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
        "SSL Capabilities Test (Single Domain)")
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
