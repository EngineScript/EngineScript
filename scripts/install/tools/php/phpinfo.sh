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

# PHPinfo.php
mkdir -p /var/www/admin/enginescript/phpinfo
echo "<?php phpinfo(); ?>" > /var/www/admin/enginescript/phpinfo/index.php

# Set Permissions
find /var/www/admin/enginescript/phpinfo -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/admin/enginescript/phpinfo -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data /var/www/admin/enginescript/phpinfo

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpinfo.php installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/phpinfo"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
