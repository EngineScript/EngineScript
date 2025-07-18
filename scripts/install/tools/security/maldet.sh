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

# Maldet Install
cd /usr/local/src
wget https://www.rfxn.com/downloads/maldetect-current.tar.gz --no-check-certificate
tar -xzf maldetect-current.tar.gz
cd maldetect-1.6.4/
./install.sh
echo "/sys" >> /usr/local/maldetect/ignore_paths

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
