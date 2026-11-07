#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# phpMyAdmin

# Store existing config file
rm -f /usr/src/config.inc.php 2>/dev/null || true
mv /var/www/admin/tools/phpmyadmin/config.inc.php /usr/src/config.inc.php
rm -rf /var/www/admin/tools/phpmyadmin

# Download phpMyAdmin
download_file "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" 2>> /tmp/enginescript_install_errors.log
unzip -q -o "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" -d /usr/src 2>> /tmp/enginescript_install_errors.log
mv "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages" /var/www/admin/tools/phpmyadmin
mkdir -p /var/www/admin/tools/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin
print_last_errors
debug_pause "phpMyAdmin Download and Extract"

# Return existing config file
mv /usr/src/config.inc.php /var/www/admin/tools/phpmyadmin/config.inc.php

# Post-Install Cleanup
run_enginescript_cleanup 2>> /tmp/enginescript_install_errors.log
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

set_install_state "PHPMYADMIN" "1"
sleep 5
