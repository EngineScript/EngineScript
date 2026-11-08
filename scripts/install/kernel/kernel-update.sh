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

# Retrieve the mainline kernel update script
download_file "https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh" "/usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh"

# Permissions
chmod +x /usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh

# Install latest kernel
bash /usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh -i --yes
apt-get install "linux-headers-$(uname -r)"
