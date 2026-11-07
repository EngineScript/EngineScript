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

# Wordfence CLI Malware scanner

# Return to /usr/src
return_to_src

# Install
download_file "https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb" "/usr/src/wordfence.deb"
apt-get install /usr/src/wordfence.deb -y

# Make Results Directory
mkdir -p /home/EngineScript/wordfence-scan-results

# Make Cache Directory
mkdir -p ~/.cache/wordfence
chmod 775 ~/.cache/wordfence

print_install_banner "Wordfence CLI" 0

# Return to /usr/src
return_to_src
