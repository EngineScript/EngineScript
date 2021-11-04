#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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

# These patches will change based on release. Don't assume they will work with a release other than the version they are intended for.

# Patch Nginx
cd /usr/src/nginx-${NGINX_VER}
patch -p1 < /usr/local/bin/enginescript/patches/nginx.patch
patch -p1 < /usr/local/bin/enginescript/patches/nginx_io_uring.patch

# Patch OpenSSL
#cd /usr/src/openssl-${OPENSSL_VER}
