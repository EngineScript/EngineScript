#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
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
    secoptions=("Configure New Domain" "MariaDB-Check Database Optimizer" "MySQLTuner" "Update Domain Vhost File" "View/Edit EngineScript Install Options File" "Remove Domain (DANGER)" "Exit Server Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Configure New Domain")
          /usr/local/bin/enginescript/scripts/install/vhost/vhost-install.sh
          break
          ;;
        "MariaDB-Check Database Optimizer")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mariadbcheck.sh
          break
          ;;
        "MySQLTuner")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mysqltuner.sh
          break
          ;;
        "Update Domain Vhost File")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "View/Edit EngineScript Install Options File")
          nano /home/EngineScript/enginescript-install-options.txt
          break
          ;;
        "Remove Domain (DANGER)")
          /usr/local/bin/enginescript/scripts/install/vhost/vhost-remove.sh
          break
          ;;
        "Exit Server Tools")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
