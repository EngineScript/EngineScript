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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script


# Ensure OCSP stapling is disabled
SSL_SHARED_CONF="/etc/nginx/ssl/sslshared.conf"
if [[ -f "$SSL_SHARED_CONF" ]]; then
    sed -i 's/ssl_stapling on;/ssl_stapling off;/' "$SSL_SHARED_CONF"
    sed -i 's/ssl_stapling_verify on;/ssl_stapling_verify off;/' "$SSL_SHARED_CONF"
fi
