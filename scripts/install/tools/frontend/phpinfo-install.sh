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

# Remove existing phpinfo directory if it exists
clean_directory "/var/www/admin/tools/phpinfo"

# Create phpinfo directory and file
mkdir -p "/var/www/admin/tools/phpinfo"
echo "<?php phpinfo(); ?>" > /var/www/admin/tools/phpinfo/index.php

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
