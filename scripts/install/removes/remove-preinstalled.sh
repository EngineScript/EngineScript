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

# Remove Previous Installations
apt-get remove --purge 'apache2.*' mysql-client mysql-common mysql-server 'nginx.*' 'php7\.0.*' 'php7\.1.*' 'php7\.2.*' 'php7\.3.*' 'php7\.4.*' 'php8\.0.*' 'php8\.1.*' -y

# Cleanup
run_enginescript_cleanup

echo "Remove Preinstalled Software completed successfully. Script done."
