#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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

# Calculate PHP FPM tune depending on RAM
calculate_php() {
AVAILABLE_MEMORY=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
AVERAGE_PHP_MEMORY_REQ=80
CPU_COUNT="$(nproc --all)"
PHP_FPM_MAX_CHILDREN_ALT=$((AVAILABLE_MEMORY/AVERAGE_PHP_MEMORY_REQ))
PHP_FPM_MAX_CHILDREN=$(( "$(free -m | awk 'NR==2{printf "%d", $2/80 }')" ))
PHP_FPM_SPARE_SERVERS=$(( "$(nproc --all)" * 2 ))
PHP_FPM_START_SERVERS=$(( "$(nproc --all)" * 4 ))
SERVER_MEMORY_TOTAL_01="$(free -m | awk 'NR==2{printf "%d", $2*0.01 }')"
SERVER_MEMORY_TOTAL_03=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.03 }')" ))
SERVER_MEMORY_TOTAL_13=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.13 }')" ))

sed -i "s|pm.max_children = 10|pm.max_children = ${PHP_FPM_MAX_CHILDREN}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
sed -i "s|pm.start_servers = 4|pm.start_servers = ${PHP_FPM_START_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
sed -i "s|pm.min_spare_servers = 2|pm.min_spare_servers = ${PHP_FPM_SPARE_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
sed -i "s|pm.max_spare_servers = 4|pm.max_spare_servers = ${PHP_FPM_START_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
sed -i "s|SEDOPCACHEJITBUFFER|${SERVER_MEMORY_TOTAL_03}|g" /etc/php/${PHP_VER}/fpm/php.ini
sed -i "s|SEDOPCACHEMEM|${SERVER_MEMORY_TOTAL_13}|g" /etc/php/${PHP_VER}/fpm/php.ini

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDOPCACHEINTBUF|16|g" /etc/php/${PHP_VER}/fpm/php.ini
  else
    sed -i "s|SEDOPCACHEINTBUF|${SERVER_MEMORY_TOTAL_01}|g" /etc/php/${PHP_VER}/fpm/php.ini
fi

}

# Update PHP config
cp -rf /usr/local/bin/enginescript/etc/php/php.ini /etc/php/${PHP_VER}/fpm/php.ini
cp -rf /usr/local/bin/enginescript/etc/php/php-fpm.conf /etc/php/${PHP_VER}/fpm/php-fpm.conf
cp -rf /usr/local/bin/enginescript/etc/php/www.conf /etc/php/${PHP_VER}/fpm/pool.d/www.conf
calculate_php
