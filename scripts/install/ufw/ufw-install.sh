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

source /etc/enginescript/install-state.conf
if [[ "${UFW}" = 1 ]]; then
    echo "UFW script has already run"
    exit 0
fi

# Set UFW Global Rules
/usr/local/bin/enginescript/scripts/install/ufw/ufw-rules.sh

# Set UFW Cloudflare Rules
/usr/local/bin/enginescript/scripts/install/ufw/ufw-cloudflare.sh

# Enable UFW
echo "y" | ufw enable

# Mark the installation as complete
echo "UFW=1" >> /etc/enginescript/install-state.conf
