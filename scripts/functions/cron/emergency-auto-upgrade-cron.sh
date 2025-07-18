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

# Get Latest Version
wget -O /usr/local/bin/enginescript/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh https://raw.githubusercontent.com/EngineScript/EngineScript/master/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh --no-check-certificate
sudo bash /usr/local/bin/enginescript/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh
