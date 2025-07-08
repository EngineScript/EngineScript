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

# Remove existing phpinfo directory if it exists
if [[ -d "/var/www/admin/enginescript/phpinfo" ]]; then
  rm -rf "/var/www/admin/enginescript/phpinfo"
fi

# Create phpinfo directory and file
mkdir -p "/var/www/admin/enginescript/phpinfo"
echo "<?php phpinfo(); ?>" > /var/www/admin/enginescript/phpinfo/index.php

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
