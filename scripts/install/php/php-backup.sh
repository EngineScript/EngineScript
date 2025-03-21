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

# Backup existing PHP config
cp -rf /etc/php/${PHP_VER}/fpm/php.ini /home/EngineScript/config-backups/php/php.ini
cp -rf /etc/php/${PHP_VER}/fpm/php-fpm.conf /home/EngineScript/config-backups/php/php-fpm.conf
cp -rf /etc/php/${PHP_VER}/fpm/pool.d/www.conf /home/EngineScript/config-backups/php/www.conf

echo ""
echo "Backing up existing php config. Backup can be found in /home/EngineScript/config-backups/php"
echo ""

sleep 2
