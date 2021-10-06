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

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh

# Brotli
#/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh

# Retrive Latest Cloudflare Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh

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
