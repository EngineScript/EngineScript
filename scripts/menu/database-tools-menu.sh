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
    secoptions=("Analyze All Tables & Databases" "MariaDB-Check Database Optimizer" "MySQLreport" "MySQLtuner" "Exit Server Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Analyze All Tables & Databases")
          /usr/local/bin/enginescript/scripts/functions/server-tools/analyze-tables.sh
          echo ""
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "MariaDB-Check Database Optimizer")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mariadbcheck.sh
          echo ""
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "MySQLreport")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mysqltuner.sh
          echo ""
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "MySQLtuner")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mysqltuner.sh
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
