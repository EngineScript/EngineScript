#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Maldet Install
cd /usr/local/src || { echo "Error: Failed to change to /usr/local/src" >&2; exit 1; }
download_and_extract "https://www.rfxn.com/downloads/maldetect-current.tar.gz" "/usr/local/src/maldetect-current.tar.gz" "/usr/local/src"
cd /usr/local/src/maldetect-*/ || { echo "Error: Failed to locate extracted maldetect directory in /usr/local/src" >&2; exit 1; }
./install.sh || { echo "Error: Maldet installation failed while running install.sh" >&2; exit 1; }
echo "/sys" >> /usr/local/maldetect/ignore_paths || { echo "Error: Failed to update maldetect ignore_paths" >&2; exit 1; }

print_install_banner "Maldet"
