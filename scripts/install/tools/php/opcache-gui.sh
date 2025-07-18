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

# Remove existing OpCache-GUI directory if it exists
if [[ -d "/var/www/admin/enginescript/opcache-gui" ]]; then
  rm -rf /var/www/admin/enginescript/opcache-gui
fi

# OpCache-GUI
git clone --depth 1 https://github.com/amnuts/opcache-gui.git /var/www/admin/enginescript/opcache-gui

# Return to /usr/src
cd /usr/src
