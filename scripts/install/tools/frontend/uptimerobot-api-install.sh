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

# Install Uptime Robot API Key
# Create Uptime Robot configuration file if it doesn't exist
if [[ ! -f "/etc/enginescript/uptimerobot.conf" ]]; then
    cp /usr/local/bin/enginescript/config/etc/enginescript/uptimerobot.conf /etc/enginescript/uptimerobot.conf
    chmod 600 /etc/enginescript/uptimerobot.conf
    chown -R www-data:www-data /etc/enginescript/uptimerobot.conf
fi

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
