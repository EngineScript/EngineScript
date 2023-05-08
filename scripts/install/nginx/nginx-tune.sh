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

# Tune FastCGI Cache
sed -i "s|SEDSERVERMEM03|${SERVER_MEMORY_TOTAL_03}|g" /etc/nginx/nginx.conf
sed -i "s|SEDSERVERMEM05|${SERVER_MEMORY_TOTAL_05}|g" /etc/nginx/nginx.conf

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 2800 ];
  then
    sed -i "s|SEDFCGIBUFFERS|16 16k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUFFERS|32 16k|g" /etc/nginx/nginx.conf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 2800 ];
  then
    sed -i "s|SEDFCGIBUSYBUFFERS|48k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUSYBUFFERS|64k|g" /etc/nginx/nginx.conf
fi
