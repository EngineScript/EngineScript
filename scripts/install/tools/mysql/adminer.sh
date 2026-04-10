#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


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
