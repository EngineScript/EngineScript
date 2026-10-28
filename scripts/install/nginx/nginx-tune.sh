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

# FastCGI cache index and disk limit from the shared tuning plan (enginescript-tuning.sh). The
# disk limit follows the cache filesystem's size, so the plan is rewritten if it has none.
tuning_load
if [[ -z "$(tuning_get NGINX_CACHE_ZONE_MB)" ]]; then
  tuning_write_plan || exit 1
  tuning_load
fi
sed -i "s|SEDNGINXCACHEZONE|$(tuning_get NGINX_CACHE_ZONE_MB)|g" /etc/nginx/nginx.conf
sed -i "s|SEDNGINXCACHEMAX|$(tuning_get NGINX_CACHE_MAX_MB)|g" /etc/nginx/nginx.conf

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

# CPU information (for the install log)
CPU_INFO="$(lscpu)"
echo "CPU Model: $(awk -F: '/^Model name:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' <<< "${CPU_INFO}")"
echo "CPU Threads: $(nproc)"
echo "Threads per Core: $(awk -F: '/^Thread\(s\) per core:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' <<< "${CPU_INFO}")"
echo "L3 Cache: $(awk -F: '/^L3 cache:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' <<< "${CPU_INFO}")"

# Hash bucket sizes follow the CPU's cache line size (64 bytes on most CPUs, 128 on some)
CACHE_LINE_SIZE="$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size 2> /dev/null)"
[[ "${CACHE_LINE_SIZE}" =~ ^[0-9]+$ ]] || CACHE_LINE_SIZE=64
sed -i "s|SEDHBS|${CACHE_LINE_SIZE}|g" /etc/nginx/nginx.conf
if [[ "${CACHE_LINE_SIZE}" == "128" ]];
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
# https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_cache_path
