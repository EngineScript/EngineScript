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
echo "INSTALL_WEBMIN = $INSTALL_WEBMIN"
echo "NGINX_SECURE_ADMIN = ${NGINX_SECURE_ADMIN}"
echo "SHOW_ENGINESCRIPT_HEADER = $SHOW_ENGINESCRIPT_HEADER"
echo "DAILY_LOCAL_DATABASE_BACKUP = $DAILY_LOCAL_DATABASE_BACKUP"
echo "HOURLY_LOCAL_DATABASE_BACKUP = $HOURLY_LOCAL_DATABASE_BACKUP"
echo "WEEKLY_LOCAL_WPCONTENT_BACKUP = $WEEKLY_LOCAL_WPCONTENT_BACKUP"
echo "INSTALL_S3_BACKUP = $INSTALL_S3_BACKUP"
echo "DAILY_S3_DATABASE_BACKUP = $DAILY_S3_DATABASE_BACKUP"
echo "HOURLY_S3_DATABASE_BACKUP = $HOURLY_S3_DATABASE_BACKUP"
echo "WEEKLY_S3_WPCONTENT_BACKUP = $WEEKLY_S3_WPCONTENT_BACKUP"
echo "INSTALL_DROPBOX_BACKUP = $INSTALL_DROPBOX_BACKUP"
echo "DAILY_DROPBOX_DATABASE_BACKUP = $DAILY_DROPBOX_DATABASE_BACKUP"
echo "HOURLY_DROPBOX_DATABASE_BACKUP = $HOURLY_DROPBOX_DATABASE_BACKUP"
echo "WEEKLY_DROPBOX_WPCONTENT_BACKUP = $WEEKLY_DROPBOX_WPCONTENT_BACKUP"

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nServer Info\n=-=-=-=-=-=-=-=-=-\n"
echo "Variables File Date = $VARIABLES_DATE"
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $UBUNTU_TYPE $UBUNTU_VERSION $UBUNTU_CODENAME"

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -Vv
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
