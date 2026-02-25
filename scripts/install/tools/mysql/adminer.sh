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

# Adminer
mkdir -p /var/www/admin/tools/adminer
safe_wget "https://www.adminer.org/latest.php" "/var/www/admin/tools/adminer/index.php"

# Set Permissons
chown -R www-data:www-data /var/www/admin/tools/adminer
find /var/www/admin/tools/adminer -type d -exec chmod 755 {} \;
find /var/www/admin/tools/adminer -type f -exec chmod 644 {} \;

print_install_banner "Adminer"
