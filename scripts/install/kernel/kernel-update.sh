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

# Retrieve  mainline kernal update script
safe_wget "https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh" "/usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh"

# Permissions
chmod +x /usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh

# Install latest kernel
bash /usr/local/bin/enginescript/scripts/install/kernel/ubuntu-mainline-kernel.sh -i --yes
sudo apt install linux-headers-$(uname -r)
