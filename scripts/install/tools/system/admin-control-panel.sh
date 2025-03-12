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

# Return to /usr/src
cd /usr/src

# phpSysinfo
rm -rf /var/www/admin/enginescript/phpsysinfo
git clone --depth 1 https://github.com/phpsysinfo/phpsysinfo.git /var/www/admin/enginescript/phpsysinfo
cp -rf /usr/local/bin/enginescript/config/var/www/admin/phpsysinfo/phpsysinfo.ini /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini
sed -i "s|SEDPHPVER|${PHP_VER}|g" /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini

# Admin Control Panel
cp -a /usr/local/bin/enginescript/config/var/www/admin/control-panel/. /var/www/admin/enginescript/

# PHPinfo.php
mkdir -p /var/www/admin/enginescript/phpinfo
echo "<?php phpinfo(); ?>" > /var/www/admin/enginescript/phpinfo/index.php

# Set Permissions
find /var/www/admin/enginescript -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/admin/enginescript -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data /var/www/admin/enginescript

# Return to /usr/src
cd /usr/src
