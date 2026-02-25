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
download_and_extract "https://www.rfxn.com/downloads/maldetect-current.tar.gz" "/usr/local/src/maldetect-current.tar.gz" "/usr/local/src"
cd maldetect-1.6.4/
./install.sh
echo "/sys" >> /usr/local/maldetect/ignore_paths

print_install_banner "Maldet"
