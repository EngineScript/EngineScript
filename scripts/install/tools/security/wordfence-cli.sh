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

# Wordfence CLI Malware scanner

# Return to /usr/src
cd /usr/src

# Install
wget -O /usr/src/wordfence.deb https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb --no-check-certificate
sudo apt install /usr/src/wordfence.deb -y

# Make Results Directory
mkdir -p /home/EngineScript/wordfence-scan-results

# Make Cache Directory
mkdir -p ~/.cache/wordfence
chmod 775 ~/.cache/wordfence

echo ""
echo ""
echo "============================================================"
echo ""
echo "${BOLD}Wordfence CLI installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

# Return to /usr/src
cd /usr/src
