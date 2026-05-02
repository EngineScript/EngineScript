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
          for ver in "${SUPPORTED_PHP_VERSIONS[@]}"; do
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
          
          # Build dynamic options in reverse order (newest first)
          php_options=()
          for (( idx=${#SUPPORTED_PHP_VERSIONS[@]}-1 ; idx>=0 ; idx-- )) ; do
              php_options+=("PHP ${SUPPORTED_PHP_VERSIONS[idx]}")
          done
          php_options+=("Cancel")
          
          select php_choice in "${php_options[@]}"; do
              if [[ "$php_choice" == "Cancel" ]]; then
                  TARGET_VER=""
                  break
              elif [[ "$php_choice" == PHP\ * ]]; then
                  TARGET_VER="${php_choice#PHP }"
                  break
              else
                  echo "Invalid option"
              fi
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
