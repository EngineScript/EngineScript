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

    echo ""
    echo "==============================================================="
    echo "EngineScript - Menu"
    echo "==============================================================="
    echo ""
    echo "Admin Control Panels:"
    echo "PHPInfo - https://${IP_ADDRESS}/enginescript/phpinfo"
    echo "Adminer - https://${IP_ADDRESS}/enginescript/adminer"
    echo "phpMyAdmin - https://${IP_ADDRESS}/enginescript/phpmyadmin"
    echo ""
    echo "Helpful Commands:"
    echo "es.config  - Open the configuration file in Nano"
    echo "es.debug   - Display debug information for EngineScript"
    echo "es.help    - Display EngineScript commands and locations"
    echo "es.menu    - Open EngineScript menu"
    echo "es.restart - Restart Nginx and PHP-FPM"
    echo "es.update  - Update and upgrade your server using APT"
    echo ""
    echo "---------------------------------------------------------------"
    echo ""
    echo "What would you like to do?"
    echo ""

    PS3='Please enter your choice: '
    options=("Domain Configuration Tools" "Backup Tools" "Site Maintenance Tools" "Database Tools" "Security Tools" "Server Tools" "EngineScript Tools" "View Server Logs" "Update Software" "Exit EngineScript")
    select opt in "${options[@]}"
    do
      case $opt in
        "Domain Configuration Tools")
          /usr/local/bin/enginescript/scripts/menu/domain-configuration-tools-menu.sh
          break
          ;;
        "Backup Tools")
          /usr/local/bin/enginescript/scripts/menu/backup-tools-menu.sh
          break
          ;;
        "Site Maintenance Tools")
          /usr/local/bin/enginescript/scripts/menu/site-maintenance-tools-menu.sh
          break
          ;;
        "Database Tools")
          /usr/local/bin/enginescript/scripts/menu/database-tools-menu.sh
          break
          ;;
        "Security Tools")
          /usr/local/bin/enginescript/scripts/menu/security-tools-menu.sh
          break
          ;;
        "Server Tools")
          /usr/local/bin/enginescript/scripts/menu/server-tools-menu.sh
          break
          ;;
        "EngineScript Tools")
          /usr/local/bin/enginescript/scripts/menu/enginescript-tools-menu.sh
          break
          ;;
        "View Server Logs")
          /usr/local/bin/enginescript/scripts/menu/logs-menu.sh
          break
          ;;
        "Update Software")
          /usr/local/bin/enginescript/scripts/menu/update-menu.sh
          break
          ;;
        "Exit EngineScript")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
