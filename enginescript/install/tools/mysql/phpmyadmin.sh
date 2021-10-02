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

# phpMyAdmin
sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -yq install phpmyadmin'
ln -s /usr/share/phpmyadmin/ /var/www/admin/enginescript

# Login Credentials
mysql -u root -p$MARIADB_ADMIN_PASSWORD -e "CREATE USER ${PHPMYADMIN_USERNAME}@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
mysql -u root -p$MARIADB_ADMIN_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO ${PHPMYADMIN_USERNAME}@'localhost'; FLUSH PRIVILEGES;"

# Post-Install Cleanup
/usr/local/bin/enginescript/enginescript/functions/enginescript-cleanup.sh

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
