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

#----------------------------------------------------------------------------

# Update Wordfence CLI

download_file "https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb" "/usr/src/wordfence.deb" 2>> "${ES_STEP_ERROR_LOG}"
if apt-get install /usr/src/wordfence.deb -y 2>> "${ES_STEP_ERROR_LOG}"; then
    echo "Wordfence CLI update completed successfully."
else
    echo "Wordfence CLI update failed. Please check the output above for details." >&2
fi
print_last_errors
debug_pause "Wordfence CLI Update"
