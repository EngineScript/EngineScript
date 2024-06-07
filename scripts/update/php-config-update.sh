#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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
  #PHP_FPM_MAX_CHILDREN_ALT=$((AVAILABLE_MEMORY/AVERAGE_PHP_MEMORY_REQ))
  #PHP_FPM_MAX_CHILDREN=$(( "$(free -m | awk 'NR==2{printf "%d", $2/80 }')" ))
  PHP_FPM_SPARE_SERVERS=$(( "$(nproc --all)" * 2 ))
  PHP_FPM_START_SERVERS=$(( "$(nproc --all)" * 4 ))
  SERVER_MEMORY_TOTAL_01="$(free -m | awk 'NR==2{printf "%d", $2*0.01 }')"
  SERVER_MEMORY_TOTAL_03=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.03 }')" ))
  SERVER_MEMORY_TOTAL_13=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.13 }')" ))

  #sed -i "s|pm.max_children = 10|pm.max_children = ${PHP_FPM_MAX_CHILDREN}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  sed -i "s|pm.start_servers = 4|pm.start_servers = ${PHP_FPM_START_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  sed -i "s|pm.min_spare_servers = 2|pm.min_spare_servers = ${PHP_FPM_SPARE_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  sed -i "s|pm.max_spare_servers = 4|pm.max_spare_servers = ${PHP_FPM_START_SERVERS}|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf

  # Tuning pm.max_children
  # For Servers with 1GB RAM
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1000 ];
    then
      sed -i "s|pm.max_children = 10|pm.max_children = 7|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

  # For Servers with 2GB RAM
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 2000 ];
    then
      sed -i "s|pm.max_children = 10|pm.max_children = 14|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

  # For Servers with 4GB RAM
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 4000 ];
    then
      sed -i "s|pm.max_children = 10|pm.max_children = 28|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

  # For Servers with 8GB RAM+
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 128000 ];
    then
      sed -i "s|pm.max_children = 10|pm.max_children = 56|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

  # Memory Limit
  # For Servers with 2GB RAM or less
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 2000 ];
    then
      sed -i "s|memory_limit = SEDMEMLM|memory_limit = 265M|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

  # For Servers with 8GB RAM+
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 128000 ];
    then
      sed -i "s|memory_limit = SEDMEMLM|memory_limit = 512M|g" /etc/php/${PHP_VER}/fpm/pool.d/www.conf
  fi

# OpCache Tuning
  if [ "${SERVER_MEMORY_TOTAL_100}" -lt 2000 ];
    then
      sed -i "s|SEDOPCACHEINTBUF|16|g" /etc/php/${PHP_VER}/fpm/php.ini
    else
      sed -i "s|SEDOPCACHEINTBUF|64|g" /etc/php/${PHP_VER}/fpm/php.ini
  fi

  sed -i "s|SEDOPCACHEJITBUFFER|${SERVER_MEMORY_TOTAL_03}|g" /etc/php/${PHP_VER}/fpm/php.ini
  sed -i "s|SEDOPCACHEMEM|${SERVER_MEMORY_TOTAL_08}|g" /etc/php/${PHP_VER}/fpm/php.ini

}

# Update PHP config
cp -rf /usr/local/bin/enginescript/etc/php/php.ini /etc/php/${PHP_VER}/fpm/php.ini
cp -rf /usr/local/bin/enginescript/etc/php/php-fpm.conf /etc/php/${PHP_VER}/fpm/php-fpm.conf
cp -rf /usr/local/bin/enginescript/etc/php/www.conf /etc/php/${PHP_VER}/fpm/pool.d/www.conf
calculate_php
