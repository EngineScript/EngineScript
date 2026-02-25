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

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# phpSysinfo
# Clone the phpSysinfo repository
git_clone_fresh "https://github.com/phpsysinfo/phpsysinfo.git" "/var/www/admin/tools/phpsysinfo" --depth 1

# Copy EngineScript phpSysinfo configuration template
# Config templates are stored in /config/var/www/admin/tools/ to mirror the install location
cp -rf /usr/local/bin/enginescript/config/var/www/admin/tools/phpsysinfo/phpsysinfo.ini /var/www/admin/tools/phpsysinfo/phpsysinfo.ini
sed -i "s|SEDPHPVER|${PHP_VER}|g" /var/www/admin/tools/phpsysinfo/phpsysinfo.ini

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
