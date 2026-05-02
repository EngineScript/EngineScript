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

# Return to /usr/src
return_to_src

# Remove existing Nginx source directory if it exists
clean_directory "/usr/src/nginx-${NGINX_VER}"

# Download and extract Nginx
download_and_extract "https://nginx.org/download/nginx-${NGINX_VER}.tar.gz" "/usr/src/nginx-${NGINX_VER}.tar.gz" || { echo "Error: Failed to download/extract Nginx."; exit 1; }

# Download and extract Headers More module
download_and_extract "https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_HEADER_VER}.tar.gz" "/usr/src/v${NGINX_HEADER_VER}.tar.gz" || { echo "Error: Failed to download/extract Headers More module."; exit 1; }

# Download and extract Cache Purge module
download_and_extract "https://github.com/nginx-modules/ngx_cache_purge/archive/${NGINX_PURGE_VER}.tar.gz" "/usr/src/${NGINX_PURGE_VER}.tar.gz" || { echo "Error: Failed to download/extract Cache Purge module."; exit 1; }
