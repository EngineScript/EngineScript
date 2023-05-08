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

# phpMyAdmin
rm -r /var/www/admin/enginescript/phpmyadmin
wget -O /usr/local/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip --no-check-certificate
unzip /usr/local/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip
mv phpMyAdmin-${PHPMYADMIN_VER}-all-languages phpmyadmin
mv phpmyadmin /var/www/admin/enginescript
sed -e "s|cfg\['blowfish_secret'\] = ''|cfg\['blowfish_secret'\] = '$RAND_CHAR32'|" /var/www/admin/enginescript/phpmyadmin/config.sample.inc.php > /var/www/admin/enginescript/phpmyadmin/config.inc.php
mkdir -p /var/www/admin/enginescript/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/enginescript/phpmyadmin

# Post-Install Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpMyAdmin updated to version ${PHPMYADMIN_VER}.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/phpmyadmin"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
