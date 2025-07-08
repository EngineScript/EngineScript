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

# phpSysinfo
# Remove existing phpSysinfo directory if it exists
if [[ -d "/var/www/admin/enginescript/phpsysinfo" ]]; then
  rm -rf /var/www/admin/enginescript/phpsysinfo
fi

# Clone the phpSysinfo repository
git clone --depth 1 https://github.com/phpsysinfo/phpsysinfo.git /var/www/admin/enginescript/phpsysinfo
cp -rf /usr/local/bin/enginescript/config/var/www/admin/phpsysinfo/phpsysinfo.ini /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini
sed -i "s|SEDPHPVER|${PHP_VER}|g" /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
