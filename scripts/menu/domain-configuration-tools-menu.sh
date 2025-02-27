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
    secoptions=("Add Domain" "Update Domain Vhost File" "Remove Domain (DANGER)" "Exit Domain Configuration Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Add Domain")
          /usr/local/bin/enginescript/scripts/install/vhost/vhost-install.sh
          break
          ;;
        "Update Domain Vhost File")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "Remove Domain (DANGER)")
          /usr/local/bin/enginescript/scripts/install/vhost/vhost-remove.sh
          break
          ;;
        "Exit Domain Configuration Tools")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
