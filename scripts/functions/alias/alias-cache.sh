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

# Clear all caches, transients, and rewrites for all sites
clear_all_wordpress_caches

# Clear system caches (Nginx, OpCache, Redis)
clear_all_system_caches

# Restart services
restart_service "nginx"
restart_php_fpm
restart_service "redis-server"

echo "All caches cleared and services restarted successfully."
