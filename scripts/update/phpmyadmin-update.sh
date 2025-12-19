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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# phpMyAdmin

# Store existing config file
rm -rf /usr/src/config.inc.php 2>/dev/null || true
mv /var/www/admin/tools/phpmyadmin/config.inc.php /usr/src/config.inc.php
rm -rf /var/www/admin/tools/phpmyadmin

# Download phpMyAdmin
wget -O "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" --no-check-certificate
unzip "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" -d /usr/src
mv "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages" /var/www/admin/tools/phpmyadmin
mkdir -p /var/www/admin/tools/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin

# Return existing config file
mv /usr/src/config.inc.php /var/www/admin/tools/phpmyadmin/config.inc.php

# Post-Install Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpMyAdmin updated to version ${PHPMYADMIN_VER}.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
