#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filename
NGINX_FILE="${NOW}-nginx-vhost.conf.gz"

# Backup Nginx Config
tar -zcf "/home/EngineScript/config-backups/nginx/${NGINX_FILE}" /etc/nginx

# Remove Old Nginx Backups
find /home/EngineScript/config-backups/nginx -type f -mtime +15 -delete
