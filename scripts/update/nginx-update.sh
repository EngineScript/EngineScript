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

# EngineScript Update (Makes sure we're installing latest Nginx)
/usr/local/bin/enginescript/scripts/update/enginescript-update.sh

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh

# Retrieve  Latest Cloudflare Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh

# Retrieve  Latest PCRE2
/usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh

# Brotli
#/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh

# Patch Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-patch.sh

# Compile Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-compile.sh

# Misc Nginx Stuff
/usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh

# Tune Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh

# Remove .default Files
rm -rf /etc/nginx/*.default

# Remove debug symbols
strip -s /usr/sbin/nginx

service nginx restart
