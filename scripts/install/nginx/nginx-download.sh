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

cd /usr/src

# Remove existing Nginx source directory if it exists
if [ -d "/usr/src/nginx-${NGINX_VER}" ]; then
  rm -rf "/usr/src/nginx-${NGINX_VER}"
fi

# Download and extract Nginx
wget "https://nginx.org/download/nginx-${NGINX_VER}.tar.gz" -O "/usr/src/nginx-${NGINX_VER}.tar.gz" --no-check-certificate || { echo "Error: Failed to download Nginx."; exit 1; }
tar -xzvf "/usr/src/nginx-${NGINX_VER}.tar.gz" || { echo "Error: Failed to extract Nginx."; exit 1; }

# Download and extract Headers More module
wget "https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_HEADER_VER}.tar.gz" -O "/usr/src/v${NGINX_HEADER_VER}.tar.gz" --no-check-certificate || { echo "Error: Failed to download Headers More module."; exit 1; }
tar -xzf "/usr/src/v${NGINX_HEADER_VER}.tar.gz" || { echo "Error: Failed to extract Headers More module."; exit 1; }

# Download and extract Cache Purge module
wget "https://github.com/nginx-modules/ngx_cache_purge/archive/${NGINX_PURGE_VER}.tar.gz" -O "/usr/src/${NGINX_PURGE_VER}.tar.gz" --no-check-certificate || { echo "Error: Failed to download Cache Purge module."; exit 1; }
tar -xzf "/usr/src/${NGINX_PURGE_VER}.tar.gz" || { echo "Error: Failed to extract Cache Purge module."; exit 1; }

# Download and extract OpenSSL
wget "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz" -O "/usr/src/openssl-${OPENSSL_VER}.tar.gz" --no-check-certificate || { echo "Error: Failed to download OpenSSL."; exit 1; }
tar -xzf "/usr/src/openssl-${OPENSSL_VER}.tar.gz" || { echo "Error: Failed to extract OpenSSL."; exit 1; }
