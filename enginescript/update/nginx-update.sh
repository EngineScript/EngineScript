#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/VisiStruct/EngineScript
# Author:       Peter Downey
# Company:      VisiStruct
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

# EngineScript Update (Makes sure we're installing latest Nginx)
/usr/local/bin/enginescript/enginescript/update/enginescript-update.sh

# Nginx Source Downloads
/usr/local/bin/enginescript/enginescript/install/nginx/nginx-download.sh

# Retrive Latest Cloudflare Zlib
/usr/local/bin/enginescript/enginescript/install/zlib/zlib-install.sh

# Brotli
#/usr/local/bin/enginescript/enginescript/install/nginx/nginx-brotli.sh

# Patch Nginx
/usr/local/bin/enginescript/enginescript/install/nginx/nginx-patch.sh

# Compile Nginx
/usr/local/bin/enginescript/enginescript/install/nginx/nginx-compile.sh

# Misc Nginx Stuff
/usr/local/bin/enginescript/enginescript/install/nginx/nginx-misc.sh

# Remove .default Files
rm -rf /etc/nginx/*.default

# Remove debug symbols
strip -s /usr/sbin/nginx

service nginx restart
