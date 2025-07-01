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

echo -e "\nClearing Caches\n\n"

# Include config
source /home/EngineScript/sites-list/sites.sh

# Function to clear transients on all sites
clear_transients() {
    for site in "${SITES[@]}"; do
        echo "Deleting ${site} Transients"
        cd "/var/www/sites/$site/html" || {
            echo "Error: Failed to change directory to /var/www/sites/$site/html"
        }
        wp transient delete-all --allow-root || {
            echo "Error: Failed to delete transients for ${site}"
        }
    done
}

# Function to clear Nginx cache
clear_nginx_cache() {
    echo "Clearing Nginx Cache"
    for site in "${SITES[@]}"; do
        echo "Purging Nginx Cache for ${site}"
        cd "/var/www/sites/$site/html" || {
            echo "Error: Failed to change directory to /var/www/sites/$site/html"
        }
        wp nginx-helper purge-all --allow-root || {
            echo "Error: Failed to purge Nginx cache for ${site}"
        }
    done
    rm -rf /var/cache/nginx/* || {
        echo "Error: Failed to clear Nginx cache"
    }
}

# Function to clear PHP OpCache
clear_php_opcache() {
    echo "Clearing PHP OpCache"
    rm -rf /var/cache/opcache/* || {
        echo "Error: Failed to clear PHP OpCache"
    }
}

# Function to clear Redis object cache
clear_redis_cache() {
    echo "Clearing Redis Object Cache"
    redis-cli FLUSHALL ASYNC || {
        echo "Error: Failed to clear Redis cache"
    }
}

# Clear caches
clear_transients
clear_nginx_cache
clear_php_opcache
clear_redis_cache

# Restart services
restart_service "nginx"
restart_php_fpm
restart_service "redis-server"

echo "All caches cleared and services restarted successfully."
