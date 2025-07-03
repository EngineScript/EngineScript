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

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check if es.sites alias is missing and add it if needed
if ! grep -q "alias es.sites=" /root/.bashrc; then
    echo "Adding missing es.sites alias to /root/.bashrc"
    echo 'alias es.sites="/usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh"' >> /root/.bashrc
fi
