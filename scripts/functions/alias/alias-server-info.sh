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

echo -e "${BOLD}\n\n--------------------\nConfiguration Review\n--------------------${NORMAL}"

echo -e "\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-\nEnginescript Install Options\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n"
echo "ADMIN_SUBDOMAIN = ${ADMIN_SUBDOMAIN}"
echo "AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION = $AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION"
echo "ENGINESCRIPT_AUTO_EMERGENCY_UPDATES = ${ENGINESCRIPT_AUTO_EMERGENCY_UPDATES}"
echo "ENGINESCRIPT_AUTO_UPDATE = $ENGINESCRIPT_AUTO_UPDATE"
echo "INSTALL_ADMINER = $INSTALL_ADMINER"
echo "INSTALL_EXPANDED_PHP = ${INSTALL_EXPANDED_PHP}"
echo "INSTALL_HTTP3 = ${INSTALL_HTTP3}"
echo "INSTALL_PHPMYADMIN = $INSTALL_PHPMYADMIN"
echo "ADMIN_CONTROL_PANEL_USERNAME = ${ADMIN_CONTROL_PANEL_USERNAME}"
echo "SHOW_ENGINESCRIPT_HEADER = $SHOW_ENGINESCRIPT_HEADER"
resolve_backup_settings
echo "BACKUP_DATABASE_FREQUENCY = ${BACKUP_DATABASE_FREQUENCY} (keep ${BACKUP_DATABASE_KEEP_DAYS} days)"
echo "BACKUP_FILES_FREQUENCY = ${BACKUP_FILES_FREQUENCY} (keep ${BACKUP_FILES_KEEP_COPIES} copies)"
echo "BACKUP_CONFIG_FREQUENCY = ${BACKUP_CONFIG_FREQUENCY} (keep ${BACKUP_CONFIG_KEEP_DAYS} days)"
echo "BACKUP_S3 = ${BACKUP_S3} (include configuration: ${BACKUP_S3_INCLUDE_CONFIG}, keep: ${BACKUP_S3_KEEP_DAYS:-not deleted})"
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nServer Info\n=-=-=-=-=-=-=-=-=-\n"
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $UBUNTU_TYPE $UBUNTU_VERSION $UBUNTU_CODENAME"

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -V
echo ""
echo "Nginx Executable Properties:"
checksec --format=json --file=/usr/sbin/nginx --extended | jq -r

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php -version
echo ""
php -m

echo -e "${BOLD}\n\n--------------------\nMariaDB Version\n--------------------${NORMAL}"
mariadb -V

echo -e "${BOLD}\n\n--------------------\nRedis Version\n--------------------${NORMAL}"
redis-server --version

echo ""
