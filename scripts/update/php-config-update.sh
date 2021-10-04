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
source /usr/local/bin/enginescript/scripts-variables.txt
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

# Update PHP config
cp -p /usr/local/bin/enginescript/etc/php/php.ini /etc/php/${PHP_VER}/fpm/php.ini
cp -p /usr/local/bin/enginescript/etc/php/php-fpm.conf /etc/php/${PHP_VER}/fpm/php-fpm.conf
cp -p /usr/local/bin/enginescript/etc/php/www.conf /etc/php/${PHP_VER}/fpm/pool.d/www.conf
