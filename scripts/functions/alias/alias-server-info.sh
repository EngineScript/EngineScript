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

echo -e "${BOLD}\n\n--------------------\nConfiguration Review\n--------------------${NORMAL}"
echo -e "${BOLD}\nServer Information:${NORMAL}"
echo "Variables File Date = $VARIABLES_DATE"
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $LINUX_TYPE $UBUNTU_VER $UBUNTU_CODENAME"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo -e "${BOLD}\nInstall Options:${NORMAL}"
echo "AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION = $AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION"
echo "AUTOMATIC_ENGINESCRIPT_UPDATES = $AUTOMATIC_ENGINESCRIPT_UPDATES"
echo "INSTALL_ADMINER = $INSTALL_ADMINER"
echo "INSTALL_PHPMYADMIN = $INSTALL_PHPMYADMIN"
echo "INSTALL_WEBMIN = $INSTALL_WEBMIN"
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
echo -e "${BOLD}\n--------------------\nNginx Version\n--------------------${NORMAL}"
nginx -Vv
echo -e "${BOLD}\n\n--------------------\nPHP Version\n--------------------${NORMAL}"
php -version
echo -e "${BOLD}\n\n--------------------\nMariaDB Version\n--------------------${NORMAL}"
mariadb -V
echo -e "${BOLD}\n\n--------------------\nRedis Version\n--------------------${NORMAL}"
redis-server --version
