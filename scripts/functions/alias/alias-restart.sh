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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Function to clear cache
clear_cache() {
    local cache_path=$1
    echo "Clearing ${cache_path} Cache"
    rm -rf ${cache_path}/* || {
        echo "Error: Failed to clear ${cache_path} cache."
    }
}

# Function to restart a service
restart_service() {
    local service_name=$1
    echo "Restarting ${service_name}"
    service ${service_name} restart || {
        echo "Error: Failed to restart ${service_name}."
    }
}

# Function to restart PHP-FPM service
restart_php_fpm() {
    local php_versions=("8.1" "8.2" "8.3" "8.4")
    for version in "${php_versions[@]}"; do
        if systemctl is-active --quiet php${version}-fpm; then
            restart_service "php${version}-fpm"
            return
        fi
    done
    echo "Error: No active PHP-FPM service found."
}

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
