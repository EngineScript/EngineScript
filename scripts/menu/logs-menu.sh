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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Server Logs" | boxes -a c -d shell -p a1l2
    echo ""
    echo "Select an option to view the last 30 lines of logs."
    echo ""
    PS3='Please enter your choice: '
    secoptions=("Domains" "MariaDB" "Nginx" "PHP" "Redis" "Syslog" "EngineScript Install Error Log" "Exit Server Logs")
    select secopt in "${secoptions[@]}"
    do
      case "$secopt" in
        "Domains")
          /usr/local/bin/enginescript/scripts/functions/logs/domain-logs.sh
          break
          ;;
        "MariaDB")
          clear
          echo "${BOLD}Showing last 30 lines of MariaDB error log.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 /var/log/mysql/mysql-error.log && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "Nginx")
          clear
          echo "${BOLD}Showing last 30 lines of Nginx error log.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 /var/log/nginx/nginx.error.log && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "PHP")
          clear
          echo "${BOLD}Showing last 30 lines of PHP error log.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 "/var/log/php/php${PHP_VER}-fpm.log" && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "Redis")
          clear
          echo "${BOLD}Showing last 30 lines of Redis error log.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 /var/log/redis/redis-server.log && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "Syslog")
          clear
          echo "${BOLD}Showing last 30 lines of Syslog.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 /var/log/syslog && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "EngineScript Install Error Log")
          clear
          echo "${BOLD}Showing last 30 lines of EngineScript install-error-log.log.${NORMAL}" | boxes -a c -d shell -p a1l2
          tail -n30 /var/log/EngineScript/install-error-log.log && read -n 1 -s -r -p "Press any key to continue"
          break
          ;;
        "Exit Server Logs")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
