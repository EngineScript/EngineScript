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

# ClamAV Install
apt install -qy clamav --no-install-recommends

# Set ClamAV Config
cp -rf /usr/local/bin/enginescript/config/etc/clamav/freshclam.conf /etc/clamav/freshclam.conf

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}ClamAV Anti-Virus installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
