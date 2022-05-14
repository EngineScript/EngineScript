#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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
wget -O /usr/local/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip
unzip /usr/local/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip
mv phpMyAdmin-${PHPMYADMIN_VER}-all-languages phpmyadmin
mv phpmyadmin /var/www/admin/enginescript
sed -e "s|cfg\['blowfish_secret'\] = ''|cfg\['blowfish_secret'\] = '$RAND_CHAR32'|" /var/www/admin/enginescript/phpmyadmin/config.sample.inc.php > /var/www/admin/enginescript/phpmyadmin/config.inc.php
mkdir -p /var/www/admin/enginescript/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/enginescript/phpmyadmin
mysql -u root -mysql -u root -p${MARIADB_ADMIN_PASSWORD} < /var/www/admin/enginescript/phpmyadmin/sql/create_tables.sql
mysql -u root -mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "CREATE USER 'pma'@'localhost' IDENTIFIED BY 'pmapass';"
mysql -u root -mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'pma'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Login Credentials
mysql -u root -mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "CREATE USER ${PHPMYADMIN_USERNAME}@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
mysql -u root -mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "GRANT ALL PRIVILEGES ON *.* TO ${PHPMYADMIN_USERNAME}@'localhost'; FLUSH PRIVILEGES;"

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
