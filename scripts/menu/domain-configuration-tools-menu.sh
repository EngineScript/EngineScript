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
    echo -e "Server Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("Create New Domain" "Import Domain" "Export Domain" "Remove Domain (DANGER)" "Exit Domain Configuration Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Create New Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-install.sh
          break
          ;;
        "Import Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-import.sh
          break
          ;;
        "Export Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-export.sh
          break
          ;;
        "Remove Domain (DANGER)")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-remove.sh
          break
          ;;
        "Exit Domain Configuration Tools")
          exit 0
          ;;
        *) echo invalid option;;
      esac
    done
  done
