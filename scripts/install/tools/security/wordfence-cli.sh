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

# Wordfence CLI Malware scanner

# Return to /usr/src
return_to_src

# Install
safe_wget "https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb" "/usr/src/wordfence.deb"
apt install /usr/src/wordfence.deb -y

# Make Results Directory
mkdir -p /home/EngineScript/wordfence-scan-results

# Make Cache Directory
mkdir -p ~/.cache/wordfence
chmod 775 ~/.cache/wordfence

print_install_banner "Wordfence CLI" 0

# Return to /usr/src
return_to_src
