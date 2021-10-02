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

# phpSysinfo
rm -rf /var/www/admin/enginescript/phpsysinfo
git clone --depth 1 https://github.com/phpsysinfo/phpsysinfo.git /var/www/admin/enginescript/phpsysinfo
cp -p /usr/local/bin/enginescript/var/www/phpsysinfo/phpsysinfo.ini /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini

# Set Permissions
find /var/www/admin/enginescript/phpsysinfo/ -type d -exec chmod 755 {} \;
find /var/www/admin/enginescript/phpsysinfo/ -type f -exec chmod 644 {} \;
chown -hR www-data:www-data /var/www/admin/enginescript/phpsysinfo/

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpSysinfo installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/phpsysinfo"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
