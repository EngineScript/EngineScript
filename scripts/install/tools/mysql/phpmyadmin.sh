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

# phpMyAdmin

# Download phpMyAdmin
wget -O "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" --no-check-certificate
unzip "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" -d "/usr/src"
mv "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages" "/var/www/admin/enginescript/phpmyadmin"
mkdir -p /var/www/admin/enginescript/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/enginescript/phpmyadmin

# phpMyAdmin Cookie Encryption
sed -e "s|cfg\['blowfish_secret'\] = ''|cfg\['blowfish_secret'\] = '$RAND_CHAR32'|" /var/www/admin/enginescript/phpmyadmin/config.sample.inc.php > /var/www/admin/enginescript/phpmyadmin/config.inc.php

# phpMyAdmin Control User (server)
sed -i "s|'pma'|'phpmyadmin_controlusr_$RAND_CHAR8'|g" /var/www/admin/enginescript/phpmyadmin/config.inc.php | sudo mariadb -e "CREATE USER 'phpmyadmin_controlusr_${RAND_CHAR8}'@'localhost' IDENTIFIED BY '${RAND_CHAR24}';"
sed -i "s|'pmapass'|'$RAND_CHAR24'|g" /var/www/admin/enginescript/phpmyadmin/config.inc.php | sudo mariadb -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin_controlusr_${RAND_CHAR8}'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Create phpMyAdmin Tables
sudo cat /var/www/admin/enginescript/phpmyadmin/sql/create_tables.sql | mariadb

# User Login Credentials
sudo mariadb -e "CREATE USER ${PHPMYADMIN_USERNAME}@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON *.* TO ${PHPMYADMIN_USERNAME}@'localhost'; FLUSH PRIVILEGES;"

# Post-Install Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpMyAdmin installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/phpmyadmin"
echo ""
echo "============================================================="
echo ""
echo ""
sleep 5
