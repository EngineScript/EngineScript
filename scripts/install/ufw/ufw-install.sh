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

# Set UFW Global Rules
/usr/local/bin/enginescript/scripts/install/ufw/ufw-rules.sh

# Set UFW Cloudflare Rules
/usr/local/bin/enginescript/scripts/install/ufw/ufw-cloudflare.sh

# Enable UFW
ufw --force enable

echo "UFW completed successfully. Script done."
