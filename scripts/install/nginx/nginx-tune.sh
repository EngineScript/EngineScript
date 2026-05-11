#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Tune FastCGI Cache
sed -i "s|SEDSERVERMEM03|${SERVER_MEMORY_TOTAL_03}|g" /etc/nginx/nginx.conf
sed -i "s|SEDSERVERMEM05|${SERVER_MEMORY_TOTAL_05}|g" /etc/nginx/nginx.conf

if [[ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ]];
  then
    sed -i "s|SEDFCGIBUFFERS|8 32k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUFFERS|16 32k|g" /etc/nginx/nginx.conf
fi

if [[ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ]];
  then
    sed -i "s|SEDFCGIBUSYBUFFERS|128k|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDFCGIBUSYBUFFERS|256k|g" /etc/nginx/nginx.conf
fi

if [[ "${SERVER_MEMORY_TOTAL_100}" -lt 1400 ]];
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

# Calculate variables_hash_bucket_size and types_hash_bucket_size
# These should be aligned to the CPU's cache line size (typically 64 bytes)
CACHE_LINE_SIZE=$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size 2>/dev/null || echo 64)
sed -i "s|SEDHBS|${CACHE_LINE_SIZE}|g" /etc/nginx/nginx.conf

# Tuning Worker Connections
# Nginx Worker Connections - scaled by RAM tier
if [[ "${SERVER_MEMORY_TOTAL_100}" -lt 1200 ]]; then
  sed -i "s|SEDNGINXRLIMIT|1024|g" /etc/nginx/nginx.conf
  sed -i "s|SEDNGINXWORKERCONNECTIONS|512|g" /etc/nginx/nginx.conf
elif [[ "${SERVER_MEMORY_TOTAL_100}" -lt 2200 ]]; then
  sed -i "s|SEDNGINXRLIMIT|2048|g" /etc/nginx/nginx.conf
  sed -i "s|SEDNGINXWORKERCONNECTIONS|1024|g" /etc/nginx/nginx.conf
elif [[ "${SERVER_MEMORY_TOTAL_100}" -lt 4200 ]]; then
  sed -i "s|SEDNGINXRLIMIT|8192|g" /etc/nginx/nginx.conf
  sed -i "s|SEDNGINXWORKERCONNECTIONS|4096|g" /etc/nginx/nginx.conf
else
  sed -i "s|SEDNGINXRLIMIT|10240|g" /etc/nginx/nginx.conf
  sed -i "s|SEDNGINXWORKERCONNECTIONS|5120|g" /etc/nginx/nginx.conf
fi

# Hash Bucket Size
NGINX_HASH_BUCKET="$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size)"
if [[ "${NGINX_HASH_BUCKET}" = 128 ]];
  then
    sed -i "s|SEDHASHBUCKETSIZE|128|g" /etc/nginx/nginx.conf
    sed -i "s|SEDHASHMAXSIZE|4096|g" /etc/nginx/nginx.conf
  else
    sed -i "s|SEDHASHBUCKETSIZE|64|g" /etc/nginx/nginx.conf
    sed -i "s|SEDHASHMAXSIZE|2048|g" /etc/nginx/nginx.conf
fi

# Keep HTTP/3 directives aligned with INSTALL_HTTP3 across core and vhost configs.
sync_nginx_http3_config

# References:
# https://www.cloudbees.com/blog/tuning-nginx
# https://serverfault.com/questions/1153941/does-anyone-have-a-best-practices-guide-for-nginx-with-http3-quic/1172800#1172800
