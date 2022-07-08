#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
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
wget https://nginx.org/download/nginx-${NGINX_VER}.tar.gz -O /usr/src/nginx-${NGINX_VER}.tar.gz && tar -xzvf /usr/src/nginx-${NGINX_VER}.tar.gz
wget https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_HEADER_VER}.tar.gz -O /usr/src/v${NGINX_HEADER_VER}.tar.gz && tar -xzf /usr/src/v${NGINX_HEADER_VER}.tar.gz
wget https://github.com/nginx-modules/ngx_cache_purge/archive/${NGINX_PURGE_VER}.tar.gz -O /usr/src/${NGINX_PURGE_VER}.tar.gz && tar -xzf /usr/src/${NGINX_PURGE_VER}.tar.gz
wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz -O /usr/src/openssl-${OPENSSL_VER}.tar.gz && tar -xzf /usr/src/openssl-${OPENSSL_VER}.tar.gz
