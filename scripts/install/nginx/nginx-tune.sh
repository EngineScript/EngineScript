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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Tune FastCGI Cache
sed -i "s|SEDSERVERMEM03|${SERVER_MEMORY_TOTAL_03}|g" /etc/nginx/nginx.conf
sed -i "s|SEDSERVERMEM05|${SERVER_MEMORY_TOTAL_05}|g" /etc/nginx/nginx.conf

if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ];
  then
    sed -i "s|SEDFCGIBUFFERS|8 32k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUFFERS|16 32k|g" /etc/nginx/nginx.conf
fi

if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ];
  then
    sed -i "s|SEDFCGIBUSYBUFFERS|128k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUSYBUFFERS|256k|g" /etc/nginx/nginx.conf
fi

if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ];
  then
    sed -i "s|SEDFCGITEMPFILEWRITESIZE|128k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGITEMPFILEWRITESIZE|256k|g" /etc/nginx/nginx.conf
fi

# Tune Nginx Threads and variables_hash_bucket_size
# Note: Nginx Threads tuning not implemented yet

# Get CPU information using lscpu and store it in a variable
CPU_INFO=$(lscpu)

# Extract specific information from the output
CPU_MODEL=$(echo "$CPU_INFO" | grep "Model name:" | awk '{print $3,$4,$5,$6,$7,$8,$9}')
CPU_CORES=$(echo "$CPU_INFO" | grep "CPU(s):" | awk '{print $2}')
CPU_THREADS=$(echo "$CPU_INFO" | grep "Thread(s) per core:" | awk '{print $4}')
CPU_CACHE=$(echo "$CPU_INFO" | grep "L1d cache:" | awk '{print $3}')

# Print the extracted information
echo "CPU Model: $CPU_MODEL"
echo "Number of Cores: $CPU_CORES"
echo "Threads per Core: $CPU_THREADS"
echo "L3 Cache: $CPU_CACHE"

# Calculate variables_hash_bucket_size
# variables_hash_bucket_size should be 2x the CPU level 1 cache value
sed -i "s|SEDHBS|$(lscpu | grep "L1d cache:" | awk '{print $3 * 2}')|g" /etc/nginx/nginx.conf

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

# For Servers with 8GB RAM+
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 128000 ];
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
    sed -i "s|#add_header Alt-Svc|add_header Alt-Svc|g" /etc/nginx/globals/response-headers.conf
fi

# References:
# https://www.cloudbees.com/blog/tuning-nginx
