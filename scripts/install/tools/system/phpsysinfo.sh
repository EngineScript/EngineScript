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

# phpSysinfo
rm -rf /var/www/admin/enginescript/phpsysinfo
git clone --depth 1 https://github.com/phpsysinfo/phpsysinfo.git /var/www/admin/enginescript/phpsysinfo
cp -rf /usr/local/bin/enginescript/var/www/admin/phpsysinfo/phpsysinfo.ini /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini

# Set Permissions
find /var/www/admin/enginescript/phpsysinfo -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/admin/enginescript/phpsysinfo -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data /var/www/admin/enginescript/phpsysinfo

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
