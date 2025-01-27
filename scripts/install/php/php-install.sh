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

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

# Install PHP
# Define the PHP packages to install
php_packages="php${PHP_VER} php${PHP_VER}-bcmath php${PHP_VER}-common php${PHP_VER}-curl php${PHP_VER}-fpm php${PHP_VER}-gd php${PHP_VER}-imagick php${PHP_VER}-intl php${PHP_VER}-mbstring php${PHP_VER}-mysql php${PHP_VER}-opcache php${PHP_VER}-redis php${PHP_VER}-ssh2 php${PHP_VER}-xml php${PHP_VER}-zip"

# Install the packages with error checking
apt install -qy $php_packages || {
  echo "Error: Unable to install one or more packages. Exiting..."
    exit 1
}

if [ "$INSTALL_EXPANDED_PHP" = 1 ];
	then
    expanded_php_packages="php${PHP_VER}-igbinary php${PHP_VER}-readline php${PHP_VER}-soap php${PHP_VER}-sqlite3"

    # Install the packages with error checking
    apt install -qy $expanded_php_packages || {
      echo "Error: Unable to install one or more packages. Exiting..."
      exit 1
    }
fi

# Logrotate
cp -rf /usr/local/bin/enginescript/etc/logrotate.d/opcache /etc/logrotate.d/opcache
sed -i "s|rotate 12|rotate 5|g" /etc/logrotate.d/php${PHP_VER}-fpm

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/cron/php-backup.sh

# Update PHP config
/usr/local/bin/enginescript/scripts/update/php-config-update.sh

mkdir -p /var/cache/opcache
mkdir -p /var/cache/php-sessions
mkdir -p /var/cache/wsdlcache
mkdir -p /var/log/opcache
mkdir -p /var/log/php

touch /var/log/opcache/opcache.log
touch /var/log/php/php${PHP_VER}-fpm.log
#touch /var/log/php/php.log
#touch /var/log/php/php-www.log
#touch /var/log/php/php-fpm.log

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

# Restart PHP
service php${PHP_VER}-fpm restart

# PHP Service Check
STATUS="$(systemctl is-active php${PHP_VER}-fpm)"
if [ "${STATUS}" = "active" ]; then
  echo "PASSED: PHP ${PHP_VER} is running."
  echo "PHP=1" >> /home/EngineScript/install-log.txt
else
  echo "FAILED: PHP ${PHP_VER} not running. Please diagnose this issue before proceeding."
  exit 1
fi

echo ""
echo "============================================================="
echo ""
echo "PHP ${PHP_VER} setup completed."
echo ""
echo "============================================================="
echo ""

sleep 5

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# References:
# https://make.wordpress.org/hosting/handbook/server-environment/#php-extensions
