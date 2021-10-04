#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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

    echo ""
    echo ""
    echo "==============================================================="
    echo "EngineScript - Advanced WordPress LEMP Server Installation"
    echo "==============================================================="
    echo ""
    echo "EngineScript is an automated, high-performance WordPress LEMP server installation tool."
    echo ""
    echo "To learn more about EngineScript, visit:"
    echo "https://github.com/Enginescript/EngineScript"
    echo ""
    echo "EngineScript Requires:"
    echo "  - Ubuntu 20.04 focal"
    echo "  - Cloudflare"
    echo "  - 30 minutes of your time"
    echo ""
    echo "Ready to get started?"
    echo ""
    echo "EngineScript is installed and active."
    echo ""
    echo "Helpful commands:"
    echo ""
    echo "es.menu - open EngineScript menu"
    echo "es.mysql - display your MySQL root password (username is root)"
    echo "es.restart - Restart Nginx and PHP-FPM"
    echo "es.update - update and upgrade your server using APT"
    echo ""
    echo "---------------------------------------------------------------"
    echo ""
    echo "What would you like to do?"
    echo ""

    PS3='Please enter your choice: '
    options=("Configure New Domain" "Update EngineScript" "Security Scanners" "Change EngineScript Install Options" "Update Existing Domain Vhost File" "Update Nginx" "Update PHP" "Update MariaDB" "Update Server Management Tools" "Exit EngineScript")
    select opt in "${options[@]}"
    do
      case $opt in
        "Configure New Domain")
          /usr/local/bin/enginescript/enginescript/install/vhost/vhost-install.sh
          break
          ;;
        "Update EngineScript")
          /usr/local/bin/enginescript/enginescript/update/enginescript-update.sh
          break
          ;;
        "Security Scanners")
          /usr/local/bin/enginescript/enginescript/menu/security-tools-menu.sh
          break
          ;;
        "Change EngineScript Install Options")
          nano /home/enginescript-install-options.txt
          sleep 3
          break
          ;;
        "Update Existing Domain Vhost File")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "Update Nginx")
          /usr/local/bin/enginescript/enginescript/update/nginx-update.sh
          sleep 3
          break
          ;;
        "Update PHP")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "Update MariaDB")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "Update Server Management Tools")
          echo "Option coming soon"
          sleep 3
          break
          ;;
        "Change EngineScript Software Versions")
          nano /usr/local/bin/enginescript/enginescript-variables.txt
          sleep 3
          break
          ;;
        "Exit EngineScript")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
