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

# Start Main Script

echo -e "\nRestarting Services\n\n"

clear_cache "/var/cache/nginx"
clear_cache "/var/cache/opcache"
echo "Clearing Redis Object Cache"
redis-cli FLUSHALL ASYNC || {
    echo "Error: Failed to clear Redis cache."
}

restart_service "nginx"
restart_php_fpm
restart_service "redis-server"

echo "All services restarted successfully."
