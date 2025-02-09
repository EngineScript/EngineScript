#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

cd /usr/src
rm -rf /usr/src/nginx-${NGINX_VER}
wget https://nginx.org/download/nginx-${NGINX_VER}.tar.gz -O /usr/src/nginx-${NGINX_VER}.tar.gz --no-check-certificate && tar -xzvf /usr/src/nginx-${NGINX_VER}.tar.gz
wget https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_HEADER_VER}.tar.gz -O /usr/src/v${NGINX_HEADER_VER}.tar.gz --no-check-certificate && tar -xzf /usr/src/v${NGINX_HEADER_VER}.tar.gz
wget https://github.com/nginx-modules/ngx_cache_purge/archive/${NGINX_PURGE_VER}.tar.gz -O /usr/src/${NGINX_PURGE_VER}.tar.gz --no-check-certificate && tar -xzf /usr/src/${NGINX_PURGE_VER}.tar.gz
wget https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz /usr/src/openssl-${OPENSSL_VER}.tar.gz --no-check-certificate && tar -xzf /usr/src/openssl-${OPENSSL_VER}.tar.gz
