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

# OPCache Logrotate
/usr/local/bin/enginescript/enginescript/install/php/php-opcache-logrotate.sh

# Backup PHP config
/usr/local/bin/enginescript/enginescript/cron/php-backup.sh

# Update PHP config
/usr/local/bin/enginescript/enginescript/update/php-config-update.sh

# Restart PHP
service php${PHP_VER}-fpm restart

mkdir -p /var/cache/opcache
mkdir -p /var/log/opcache
touch /var/log/opcache/opcache.log
chmod 775 /var/cache/opcache
chmod 775 /var/log/opcache/opcache.log
chown www-data:www-data /var/cache/opcache
chown www-data:www-data /var/log/opcache
chown www-data:www-data /var/log/opcache/opcache.log

echo ""
echo "============================================================="
echo ""
echo "PHP ${PHP_VER} setup completed."
echo ""
echo "============================================================="
echo ""

sleep 5

# Cleanup
/usr/local/bin/enginescript/enginescript/functions/enginescript-cleanup.sh
