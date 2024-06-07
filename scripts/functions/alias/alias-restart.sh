#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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

echo -e "\nRestarting Services\n\n"

echo "Clearing Nginx Cache"
rm -rf /var/cache/nginx/*
echo "Clearing PHP OpCache"
rm -rf /var/cache/opcache/*
echo "Clearing Redis Object Cache"
redis-cli FLUSHALL ASYNC
echo "Restarting Nginx"
service nginx restart
echo "Restarting PHP-FPM"
service php${PHP_VER}-fpm restart
echo "Restarting Redis"
service redis-server restart
