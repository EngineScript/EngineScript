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
# This has changed. Cloudflare is now hiding this file
# https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull#zone-level--cloudflare-certificates
# Retrieve Cloudflare Origin Certificate
#wget -O /etc/nginx/ssl/cloudflare/origin-pull-ca.pem https://support.cloudflare.com/hc/en-us/article_attachments/360044928032/origin-pull-ca.pem
