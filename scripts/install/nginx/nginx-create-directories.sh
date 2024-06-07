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

# Create Nginx Directories
mkdir -p /etc/nginx/custom-global-directives
mkdir -p /etc/nginx/custom-single-domain-directives
mkdir -p /etc/nginx/globals
mkdir -p /etc/nginx/restricted-access
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/ssl/cloudflare
mkdir -p /etc/nginx/ssl/dhe
mkdir -p /etc/nginx/ssl/localhost
mkdir -p /usr/lib/nginx/modules
mkdir -p /tmp/nginx_proxy
mkdir -p /var/cache/nginx
mkdir -p /var/lib/nginx/body
mkdir -p /var/lib/nginx/fastcgi
mkdir -p /var/lib/nginx/proxy
mkdir -p /var/log/domains
mkdir -p /var/www/admin/enginescript
mkdir -p /var/www/sites
