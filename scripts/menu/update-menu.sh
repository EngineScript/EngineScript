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
    echo -e "Update Software" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""

    PS3='Please enter your choice: '
    options=("Update EngineScript" "Update Kernel (experimental)" "Update MariaDB" "Update Nginx" "Update OpenSSL" "Update PHP" "Switch PHP Version" "Update Server Tools" "Update Ubuntu Distribution (apt full-upgrade)" "Update Ubuntu Software (apt upgrade)" "Exit Update Software Menu")
    select opt in "${options[@]}"
    do
      case $opt in
        "Update EngineScript")
          /usr/local/bin/enginescript/scripts/update/enginescript-update.sh
          break
          ;;
        "Update Kernel (experimental)")
          /usr/local/bin/enginescript/scripts/install/kernel/kernel-update.sh
          break
          ;;
        "Update MariaDB")
          /usr/local/bin/enginescript/scripts/update/mariadb-update.sh
          break
          ;;
        "Update Nginx")
          /usr/local/bin/enginescript/scripts/update/nginx-update.sh
          break
          ;;
        "Update OpenSSL")
          echo "Currently disabled as it's not needed."
          sleep 5
          #/usr/local/bin/enginescript/scripts/update/openssl-update.sh
          break
          ;;
        "Update PHP")
          /usr/local/bin/enginescript/scripts/update/php-update.sh
          break
          ;;
        "Switch PHP Version")
          echo ""
          echo "Switch PHP Version"
          echo "=================="
          echo ""
          # Detect currently installed PHP-FPM version
          CURRENT_PHP=""
          for ver in 8.3 8.4 8.5; do
              if dpkg -l 2>/dev/null | grep -q "php${ver}-fpm"; then
                  CURRENT_PHP="${ver}"
              fi
          done
          if [[ -n "${CURRENT_PHP}" ]]; then
              echo "Currently installed: PHP ${CURRENT_PHP}"
          else
              echo "No PHP-FPM installation detected."
          fi
          echo ""
          echo "Select the PHP version to switch to:"
          PS3='Choose a version: '
          select php_choice in "PHP 8.5" "PHP 8.4" "PHP 8.3" "Cancel"; do
              case $php_choice in
                  "PHP 8.5")
                      TARGET_VER="8.5"
                      break
                      ;;
                  "PHP 8.4")
                      TARGET_VER="8.4"
                      break
                      ;;
                  "PHP 8.3")
                      TARGET_VER="8.3"
                      break
                      ;;
                  "Cancel")
                      TARGET_VER=""
                      break
                      ;;
                  *) echo "Invalid option";;
              esac
          done
          if [[ -n "${TARGET_VER}" ]]; then
              if [[ "${TARGET_VER}" == "${CURRENT_PHP}" ]]; then
                  echo ""
                  echo "PHP ${TARGET_VER} is already installed. No changes needed."
                  sleep 3
              else
                  /usr/local/bin/enginescript/scripts/update/php-update.sh "${TARGET_VER}"
              fi
          fi
          break
          ;;
        "Update Server Tools")
          /usr/local/bin/enginescript/scripts/update/software-update.sh
          break
          ;;
        "Update Ubuntu Distribution (apt full-upgrade)")
          apt full-upgrade
          break
          ;;
        "Update Ubuntu Software (apt upgrade)")
          /usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh
          break
          ;;
        "Exit Update Software Menu")
          exit
          ;;
        *) echo invalid option;;
      esac
    done
  done
