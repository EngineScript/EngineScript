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

echo -e "\nClearing Caches\n\n"

# Include config
source /home/EngineScript/sites-list/sites.sh

# Clear Transients on all sites
for i in "${SITES[@]}"
do
  echo "Deleting ${i} Transients"
	cd "/var/www/sites/$i/html"
  wp transient delete-all --allow-root
done

# Clear Nginx fastCGI cache
echo "Clearing Nginx Cache"
for i in "${SITES[@]}"
do
  echo "Deleting ${i} Transients"
	cd "/var/www/sites/$i/html"
  wp nginx-helper purge-all --allow-root
done
rm -rf /var/cache/nginx/*

# Clear PHP OpCache
echo "Clearing PHP OpCache"
rm -rf /var/cache/opcache/*

# Clear Redis object cache
echo "Clearing Redis Object Cache"
redis-cli FLUSHALL ASYNC

# Restart services
echo "Restarting Nginx"
service nginx restart
echo "Restarting PHP-FPM"
service php${PHP_VER}-fpm restart
echo "Restarting Redis"
service redis-server restart
