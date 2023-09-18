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

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

apt install php${PHP_VER} php${PHP_VER}-bcmath php${PHP_VER}-bz2 php${PHP_VER}-common php${PHP_VER}-curl php${PHP_VER}-fpm php${PHP_VER}-gd php${PHP_VER}-igbinary php${PHP_VER}-imagick php${PHP_VER}-intl php${PHP_VER}-mbstring php${PHP_VER}-msgpack php${PHP_VER}-mysql php${PHP_VER}-opcache php${PHP_VER}-readline php${PHP_VER}-redis php${PHP_VER}-soap php${PHP_VER}-ssh2 php${PHP_VER}-xml php${PHP_VER}-zip -y

# Update PHP config
/usr/local/bin/enginescript/scripts/update/php-config-update.sh

find /var/log/php -type d,f -exec chmod 775 {} \;
find /var/log/opcache -type d,f -exec chmod 775 {} \;
find /etc/php -type d,f -exec chmod 775 {} \;
chmod 775 /var/cache/opcache
chmod 775 /var/cache/php-sessions
chmod 775 /var/cache/wsdlcache
chown -R www-data:www-data /var/cache/opcache
chown -R www-data:www-data /var/cache/php-sessions
chown -R www-data:www-data /var/cache/wsdlcache
chown -R www-data:www-data /var/log/opcache
chown -R www-data:www-data /var/log/php
chown -R www-data:www-data /etc/php

# Logrotate
rm -rf /etc/logrotate.d/php${OLDPHP}-fpm
cp -rf /usr/local/bin/enginescript/etc/logrotate.d/php${PHP_VER}-fpm /etc/logrotate.d/php${PHP_VER}-fpm

sed -i "s|php${OLDPHP}-fpm|php${PHP_VER}-fpm|g" /etc/nginx/globals/php.conf
sed -i "s|php${OLDPHP}-fpm|php${PHP_VER}-fpm|g" /etc/php/${PHP_VER}/fpm/php-fpm.conf
sed -i "s|php/${OLDPHP}/fpm|php/${PHP_VER}/fpm|g" /etc/php/${PHP_VER}/fpm/php-fpm.conf
sed -i "s|php${OLDPHP}-fpm|php${PHP_VER}-fpm|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf

# Block old PHP from APT
echo -e "Package: php${OLDPHP}*\nPin: release *\nPin-Priority: -1" > php${OLDPHP}-block

/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
