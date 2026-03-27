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

#----------------------------------------------------------------------------

# Update Wordfence CLI

safe_wget "https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb" "/usr/src/wordfence.deb" 2>> /tmp/enginescript_install_errors.log
if apt install /usr/src/wordfence.deb -y 2>> /tmp/enginescript_install_errors.log; then
    echo "Wordfence CLI update completed successfully."
else
    echo "Wordfence CLI update failed. Please check the output above for details." >&2
fi
print_last_errors
debug_pause "Wordfence CLI Update"
