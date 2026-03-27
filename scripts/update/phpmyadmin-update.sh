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
rm -f /usr/src/config.inc.php 2>/dev/null || true
mv /var/www/admin/tools/phpmyadmin/config.inc.php /usr/src/config.inc.php
rm -rf /var/www/admin/tools/phpmyadmin

# Download phpMyAdmin
safe_wget "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" 2>> /tmp/enginescript_install_errors.log
unzip "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" -d /usr/src 2>> /tmp/enginescript_install_errors.log
mv "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages" /var/www/admin/tools/phpmyadmin
mkdir -p /var/www/admin/tools/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin
print_last_errors
debug_pause "phpMyAdmin Download and Extract"

# Return existing config file
mv /usr/src/config.inc.php /var/www/admin/tools/phpmyadmin/config.inc.php

# Post-Install Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh 2>> /tmp/enginescript_install_errors.log
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "phpMyAdmin Cleanup"

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
