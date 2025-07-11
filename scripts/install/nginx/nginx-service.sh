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

# Nginx Service
rm -rf /usr/lib/systemd/system/nginx.service
cp -rf /usr/local/bin/enginescript/config/etc/systemd/system/nginx.service /etc/systemd/system/nginx.service
chmod 644 /etc/systemd/system/nginx.service
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx
