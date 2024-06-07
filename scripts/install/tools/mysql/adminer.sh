#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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

# Adminer
mkdir /var/www/admin/enginescript/adminer
wget https://www.adminer.org/latest.php -O /var/www/admin/enginescript/adminer/index.php --no-check-certificate

# Set Permissons
chown -R www-data:www-data /var/www/admin/enginescript/adminer
find /var/www/admin/enginescript/adminer -type d -exec chmod 755 {} \;
find /var/www/admin/enginescript/adminer -type f -exec chmod 644 {} \;

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Adminer installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/adminer"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
