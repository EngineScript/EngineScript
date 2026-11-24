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

# Filename: a zstd tar of /etc/nginx (until 2026-11-20 a gzip tar named <date>-nginx-vhost.conf.gz)
NGINX_FILE="${NOW}-nginx.tar.zst"

# Backup Nginx Config
tar -C / "${ES_TAR_ZSTD}" -cf "/home/EngineScript/config-backups/nginx/${NGINX_FILE}" etc/nginx

# Remove Old Nginx Backups (either name)
find /home/EngineScript/config-backups/nginx -type f -mtime +15 -delete
