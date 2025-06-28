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
    secoptions=("Backup (All Domains)" "Exit Server Tools")
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
        "Exit Server Tools")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
