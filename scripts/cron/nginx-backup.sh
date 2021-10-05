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

#----------------------------------------------------------------------------

# Filenames
NOW=$(date +%m-%d-%Y-%H%M)
NGINX_FILE="${NOW}-nginx.tar.gz";

# Backup Nginx Config
tar -zcf "/home/EngineScript/config-backups/nginx/$NGINX_FILE" /etc/nginx

# Remove Old Nginx Backups
find /home/EngineScript/config-backups/nginx -type f -mtime +15 | xargs rm -fR
