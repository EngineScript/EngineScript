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

# Return to /usr/src
cd /usr/src

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# Remove existing OpCache-GUI directory if it exists
if [[ -d "/var/www/admin/tools/opcache-gui" ]]; then
  rm -rf /var/www/admin/tools/opcache-gui
fi

# OpCache-GUI
git clone --depth 1 https://github.com/amnuts/opcache-gui.git /var/www/admin/tools/opcache-gui

# Return to /usr/src
cd /usr/src
