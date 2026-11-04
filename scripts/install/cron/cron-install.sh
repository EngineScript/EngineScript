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

# Copy Sites List Template
if [[ ! -f "/home/EngineScript/sites-list/sites.sh" ]]; then
    cp -rf /usr/local/bin/enginescript/scripts/functions/cron/sites.sh /home/EngineScript/sites-list/sites.sh
fi

#----------------------------------------------------------------------------------
# Set Cron Jobs
#----------------------------------------------------------------------------------

install_enginescript_cron

# Mark the installation as complete
set_install_state "CRON" "1"
echo "Cron completed successfully. Script done."
