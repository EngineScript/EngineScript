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



#----------------------------------------------------------------------------------
# Start Main Script

# Generate self-signed SSL certificate for localhost.
# This allows you to connect to your server's IP address with SSL enabled.
# Ignore browser errors related to certificate validity.

# Create Self-Signed SSL Certificate
openssl req -new -newkey rsa:4096 -sha256 -days 36500 -nodes -x509 \
-keyout /etc/nginx/ssl/localhost/localhost.key -out /etc/nginx/ssl/localhost/localhost.crt \
-subj "/C=US/ST=Florida/L=Orlando/O=EngineScript/CN=localhost" \
-addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
