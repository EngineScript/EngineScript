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

# Install PHP
apt update && apt full-upgrade -y
apt install php${PHP_VER} php${PHP_VER}-bcmath php${PHP_VER}-common php${PHP_VER}-curl php${PHP_VER}-fpm php${PHP_VER}-gd php${PHP_VER}-intl php${PHP_VER}-mbstring php${PHP_VER}-mysql php${PHP_VER}-opcache php${PHP_VER}-readline php${PHP_VER}-soap php${PHP_VER}-xml php${PHP_VER}-zip php${PHP_VER}-igbinary php${PHP_VER}-imagick php${PHP_VER}-msgpack php${PHP_VER}-redis php${PHP_VER}-ssh2 -y

# Logrotate
cp -p /usr/local/bin/enginescript/etc/logrotate.d/opcache /etc/logrotate.d/opcache
cp -p /usr/local/bin/enginescript/etc/logrotate.d/php8.0-fpm /etc/logrotate.d/php8.0-fpm

# Backup PHP config
/usr/local/bin/enginescript/scripts/cron/php-backup.sh

# Update PHP config
/usr/local/bin/enginescript/scripts/update/php-config-update.sh

mkdir -p /var/cache/opcache
mkdir -p /var/log/opcache
mkdir -p /var/log/php

touch /var/log/opcache/opcache.log
touch /var/log/php/fpm-php.www.log
touch /var/log/php/php.log

chmod 775 /var/cache/opcache
chmod 775 /var/log/opcache
chmod 775 /var/log/php
chmod 775 /var/log/opcache/opcache.log
chmod 775 /var/log/php/fpm-php.www.log
chmod 775 /var/log/php/php.log

chown -hR www-data:www-data /var/cache/opcache
chown -hR www-data:www-data /var/log/opcache
chown -hR www-data:www-data /var/log/php
chown -hR www-data:www-data /var/log/opcache/opcache.log
chown -hR www-data:www-data /var/log/php/fpm-php.www.log
chown -hR www-data:www-data /var/log/php/php.log

# Restart PHP
service php${PHP_VER}-fpm restart

echo ""
echo "============================================================="
echo ""
echo "PHP ${PHP_VER} setup completed."
echo ""
echo "============================================================="
echo ""

sleep 5

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh
