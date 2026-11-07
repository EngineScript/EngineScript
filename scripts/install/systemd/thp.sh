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

# Disable Transparent Huge Pages
cp -rf /usr/local/bin/enginescript/config/etc/systemd/system/disable-thp.service /etc/systemd/system/disable-thp.service
chmod 644 /etc/systemd/system/disable-thp.service
systemctl daemon-reload
systemctl enable disable-thp
systemctl start disable-thp

echo "Transparent Huge Pages completed successfully. Script done."
