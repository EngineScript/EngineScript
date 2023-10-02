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

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 2800 ];
  then
    sed -i "s|SEDFCGIBUSYBUFFERS|48k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUSYBUFFERS|64k|g" /etc/nginx/nginx.conf
fi

# Tuning Worker Connections
# For Servers with 1GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1000 ];
  then
    sed -i "s|SEDNGINXRLIMIT|1024|g" /etc/nginx/nginx.conf
    sed -i "s|SEDNGINXWORKERCONNECTIONS|512|g" /etc/nginx/nginx.conf
fi

# For Servers with 2GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 2000 ];
  then
    sed -i "s|SEDNGINXRLIMIT|2048|g" /etc/nginx/nginx.conf
    sed -i "s|SEDNGINXWORKERCONNECTIONS|1024|g" /etc/nginx/nginx.conf
fi

# For Servers with 4GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 4000 ];
  then
    sed -i "s|SEDNGINXRLIMIT|8192|g" /etc/nginx/nginx.conf
    sed -i "s|SEDNGINXWORKERCONNECTIONS|4096|g" /etc/nginx/nginx.conf
fi

# For Servers with 8GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 8000 ];
  then
    sed -i "s|SEDNGINXRLIMIT|10240|g" /etc/nginx/nginx.conf
    sed -i "s|SEDNGINXWORKERCONNECTIONS|5120|g" /etc/nginx/nginx.conf
fi

# Hash Bucket Size
NGINX_HASH_BUCKET="$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size)"
if [ "${NGINX_HASH_BUCKET}" = 128 ];
  then
    sed -i "s|SEDHASHBUCKETSIZE|128|g" /etc/nginx/nginx.conf
    sed -i "s|SEDHASHMAXSIZE|4096|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDHASHBUCKETSIZE|64|g" /etc/nginx/nginx.conf
    sed -i "s|SEDHASHMAXSIZE|2048|g" /etc/nginx/nginx.conf
fi

# HTTP3
if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#http3 on;|http3 on;|g" /etc/nginx/nginx.conf
fi

if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#quic_bpf on|quic_bpf on|g" /etc/nginx/nginx.conf
fi

if [ "${INSTALL_HTTP3}" = 1 ] && ethtool -k eth0 | grep "tx-gso-robust: on";
  then
    sed -i "s|#quic_gso on|quic_gso on|g" /etc/nginx/nginx.conf
fi

if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#quic_retry on|quic_retry on|g" /etc/nginx/nginx.conf
fi

if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#add_header Alt-Svc|add_header Alt-Svc|g" /etc/nginx/globals/responseheaders.conf
fi
