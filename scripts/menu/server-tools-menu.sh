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

# Main Menu
while true
  do
    clear
    echo -e "Server Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Display Server Info"
      "List Sites"
      "Restart Services (Nginx, PHP-FPM, Redis)"
      "Exit Server Tools"
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
        "List Sites")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Restart Services (Nginx, PHP-FPM, Redis)")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Exit Server Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
