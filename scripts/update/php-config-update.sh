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

# Calculate PHP FPM tune depending on RAM
calculate_php() {
  AVAILABLE_MEMORY=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
  AVERAGE_PHP_MEMORY_REQ=80
  CPU_COUNT="$(nproc --all)" # Get the number of CPU threads
  #PHP_FPM_MAX_CHILDREN_ALT=$((AVAILABLE_MEMORY/AVERAGE_PHP_MEMORY_REQ))
  #PHP_FPM_MAX_CHILDREN=$(( "$(free -m | awk 'NR==2{printf "%d", $2/80 }')" ))
  SERVER_MEMORY_TOTAL_01="$(free -m | awk 'NR==2{printf "%d", $2*0.01 }')"
  SERVER_MEMORY_TOTAL_03=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.03 }')" ))
  SERVER_MEMORY_TOTAL_13=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.13 }')" ))
  SERVER_MEMORY_TOTAL_100="$(free -m | awk 'NR==2{printf "%d", $2 }')"

  # Dynamically calculate pm.start_servers, pm.min_spare_servers, and pm.max_spare_servers based on CPU threads
  if [ "${CPU_COUNT}" -eq 1 ]; then
    PHP_FPM_START_SERVERS=2
    PHP_FPM_MIN_SPARE_SERVERS=1
    PHP_FPM_MAX_SPARE_SERVERS=3
  elif [ "${CPU_COUNT}" -eq 2 ]; then
    PHP_FPM_START_SERVERS=3
    PHP_FPM_MIN_SPARE_SERVERS=2
    PHP_FPM_MAX_SPARE_SERVERS=5
  elif [ "${CPU_COUNT}" -eq 4 ]; then
    PHP_FPM_START_SERVERS=4
    PHP_FPM_MIN_SPARE_SERVERS=3
    PHP_FPM_MAX_SPARE_SERVERS=6
  else
    PHP_FPM_START_SERVERS=5
    PHP_FPM_MIN_SPARE_SERVERS=4
    PHP_FPM_MAX_SPARE_SERVERS=7
  fi
  
  # Calculate pm.max_children based on available memory
  if [ "${AVAILABLE_MEMORY}" -lt 1200 ]; then
    PHP_FPM_MAX_CHILDREN=8
    PHP_MEMORY_LIMIT="256M"
    OPCACHE_JIT_BUFFER="64M"
    OPCACHE_INT_BUFFER=16
  elif [ "${AVAILABLE_MEMORY}" -lt 2200 ]; then
    PHP_FPM_MAX_CHILDREN=16
    PHP_MEMORY_LIMIT="256M"
    OPCACHE_JIT_BUFFER="64M"
    OPCACHE_INT_BUFFER=16
  elif [ "${AVAILABLE_MEMORY}" -lt 4200 ]; then
    PHP_FPM_MAX_CHILDREN=24
    PHP_MEMORY_LIMIT="512M"
    OPCACHE_JIT_BUFFER="96M"
    OPCACHE_INT_BUFFER=64
  else
    PHP_FPM_MAX_CHILDREN=48
    PHP_MEMORY_LIMIT="512M"
    OPCACHE_JIT_BUFFER="128M"
    OPCACHE_INT_BUFFER=64
  fi

  # Apply calculated values to PHP-FPM configuration
  sed -i "s|pm.start_servers = .*|pm.start_servers = \"${PHP_FPM_START_SERVERS}\"|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
  sed -i "s|pm.min_spare_servers = .*|pm.min_spare_servers = \"${PHP_FPM_MIN_SPARE_SERVERS}\"|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
  sed -i "s|pm.max_spare_servers = .*|pm.max_spare_servers = \"${PHP_FPM_MAX_SPARE_SERVERS}\"|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
  sed -i "s|pm.max_children = .*|pm.max_children = \"${PHP_FPM_MAX_CHILDREN}\"|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"

  # Apply memory and OpCache settings to php.ini
  sed -i "s|SEDPHPMEMLIMIT|\"${PHP_MEMORY_LIMIT}\"|g" "/etc/php/${PHP_VER}/fpm/php.ini"
  sed -i "s|SEDOPCACHEJITBUFFER|\"${OPCACHE_JIT_BUFFER}\"|g" "/etc/php/${PHP_VER}/fpm/php.ini"
  sed -i "s|SEDOPCACHEINTBUF|\"${OPCACHE_INT_BUFFER}\"|g" "/etc/php/${PHP_VER}/fpm/php.ini"
  # Arithmetic expansion result is unlikely to need quoting, but added for consistency
  sed -i "s|SEDOPCACHEMEM|\"$((AVAILABLE_MEMORY / 8))M\"|g" "/etc/php/${PHP_VER}/fpm/php.ini"
}

# Update PHP config
cp -rf /usr/local/bin/enginescript/config/etc/php/php.ini "/etc/php/${PHP_VER}/fpm/php.ini"
sed -i "s|SEDPHPVER|\"${PHP_VER}\"|g" "/etc/php/${PHP_VER}/fpm/php.ini"

cp -rf /usr/local/bin/enginescript/config/etc/php/php-fpm.conf "/etc/php/${PHP_VER}/fpm/php-fpm.conf"
sed -i "s|SEDPHPVER|\"${PHP_VER}\"|g" "/etc/php/${PHP_VER}/fpm/php-fpm.conf"

cp -rf /usr/local/bin/enginescript/config/etc/php/www.conf "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
sed -i "s|SEDPHPVER|\"${PHP_VER}\"|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"

# Tune PHP Configuration
calculate_php
