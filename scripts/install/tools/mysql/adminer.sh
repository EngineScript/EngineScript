#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# Adminer
mkdir -p /var/www/admin/tools/adminer
download_file "https://www.adminer.org/latest.php" "/var/www/admin/tools/adminer/index.php"

# Set permissions (as www-data: the folder belongs to it, so a root chmod could follow a link)
set_www_data_tree /var/www/admin/tools/adminer

print_install_banner "Adminer"
