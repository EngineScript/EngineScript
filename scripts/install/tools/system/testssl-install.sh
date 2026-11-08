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

# Return to /usr/src
return_to_src

# Install Testssl.sh
git_clone_fresh "https://github.com/testssl/testssl.sh.git" "/usr/local/bin/testssl.sh"

# Permissions
find /usr/local/bin/testssl.sh -exec chmod 755 {} +
chown -R root:root /usr/local/bin/testssl.sh
find /usr/local/bin/testssl.sh -type f -iname "*.sh" -exec chmod +x {} +

# Return to /usr/src
return_to_src
