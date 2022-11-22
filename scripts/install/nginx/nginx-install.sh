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

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh

# Brotli
#/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh

# Retrieve Latest Cloudflare Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh

# Retrieve Latest PCRE2
/usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh

# Patch Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-patch.sh

# Compile Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-compile.sh

# Create Nginx Directories
/usr/local/bin/enginescript/scripts/install/nginx/nginx-create-directories.sh

# Misc Nginx Stuff
/usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh

# Backup Nginx
/usr/local/bin/enginescript/scripts/cron/nginx-backup.sh

# Cloudflare
/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare.sh

# SSL
/usr/local/bin/enginescript/scripts/install/nginx/nginx-ssl.sh

# Assign Admin Password
/usr/local/bin/enginescript/scripts/install/nginx/nginx-admin-password.sh

# Install Nginx Service
/usr/local/bin/enginescript/scripts/install/nginx/nginx-service.sh

# Hide EngineScript Header
if [ "${SHOW_ENGINESCRIPT_HEADER}" = 1 ];
  then
    sed -i "s|#more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|g" /etc/nginx/globals/responseheaders.conf
  else
    echo ""
fi

# Nginx Installation Completed
echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Nginx installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
