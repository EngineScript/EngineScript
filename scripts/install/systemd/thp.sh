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



#----------------------------------------------------------------------------------
# Start Main Script

# Disable Transparent Huge Pages
cp -rf /usr/local/bin/enginescript/config/etc/systemd/system/disable-thp.service /etc/systemd/system/disable-thp.service
chmod 644 /etc/systemd/system/disable-thp.service
systemctl daemon-reload
systemctl enable disable-thp
systemctl start disable-thp
