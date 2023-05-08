#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
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

# Generate self-signed SSL certificate for localhost.
# This allows you to connect to your server's IP address with SSL enabled.
# Ignore browser errors related to certificate validity.

# Create Self-Signed SSL Certificate
openssl req -new -newkey rsa:2048 -days 36500 -nodes -x509 \
  -subj "/C=US/ST=Florida/L=Orlando/O=EngineScript/CN=${IP_ADDRESS}" \
  -keyout /etc/nginx/ssl/localhost/localhost.key  -out /etc/nginx/ssl/localhost/localhost.crt
