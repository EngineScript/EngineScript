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

# Remove Previous Installations: Apache, MySQL, Ubuntu's Nginx and its modules, and PHP 7.0 to 8.1.
# Only installed packages are passed to apt (see purge_installed_packages).
purge_installed_packages 'apache2*' 'mysql-client' 'mysql-common' 'mysql-server' '*nginx*' '*php7.[0-4]*' '*php8.[01]*'

# Cleanup
run_enginescript_cleanup

echo "Remove Preinstalled Software completed successfully. Script done."
