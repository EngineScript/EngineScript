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

# Allow callers such as php-update.sh to configure a newly selected target
# version without changing the persisted default/override setting.
if [[ -n "${1:-}" ]]; then
  php_target_valid=false
  for ver in "${SUPPORTED_PHP_VERSIONS[@]}"; do
    if [[ "${1}" == "${ver}" ]]; then
      php_target_valid=true
      break
    fi
  done

  if [[ "${php_target_valid}" == true ]]; then
    PHP_VER="${1}"
  else
    echo "Error: Unsupported PHP version '${1}'." >&2
    exit 1
  fi
fi


#----------------------------------------------------------------------------------
# Start Main Script

# Apply the shared tuning plan (enginescript-tuning.sh) to PHP-FPM: worker counts,
# memory_limit, and OPcache sizes. The plan is written first if the server has none yet.
apply_php_tuning() {
  local www="/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ini="/etc/php/${PHP_VER}/fpm/php.ini"

  tuning_load
  if [[ -z "$(tuning_get PHP_MAX_CHILDREN)" ]]; then
    tuning_write_plan || exit 1
    tuning_load
  fi

  sed -i "s|pm.start_servers = .*|pm.start_servers = $(tuning_get PHP_START_SERVERS)|g" "${www}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|pm.min_spare_servers = .*|pm.min_spare_servers = $(tuning_get PHP_MIN_SPARE_SERVERS)|g" "${www}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|pm.max_spare_servers = .*|pm.max_spare_servers = $(tuning_get PHP_MAX_SPARE_SERVERS)|g" "${www}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|pm.max_children = .*|pm.max_children = $(tuning_get PHP_MAX_CHILDREN)|g" "${www}" 2>> /tmp/enginescript_install_errors.log

  sed -i "s|SEDPHPMEMLIMIT|$(tuning_get PHP_MEMORY_LIMIT_MB)M|g" "${ini}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|SEDOPCACHEINTBUF|$(tuning_get OPCACHE_INTERNED_MB)|g" "${ini}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|SEDOPCACHEMEM|$(tuning_get OPCACHE_MEMORY_MB)M|g" "${ini}" 2>> /tmp/enginescript_install_errors.log
  sed -i "s|SEDOPCACHEMAXFILES|$(tuning_get OPCACHE_MAX_FILES)|g" "${ini}" 2>> /tmp/enginescript_install_errors.log
}

# Put back the configuration files saved before this run (used when the new one fails php-fpm -t)
restore_php_configs() {
  local file
  for file in "/etc/php/${PHP_VER}/fpm/php.ini" "/etc/php/${PHP_VER}/fpm/php-fpm.conf" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"; do
    if [[ -f "${file}.bak" ]]; then
      cp -p "${file}.bak" "${file}"
    fi
  done
}

# Update PHP config
if [ -f "/etc/php/${PHP_VER}/fpm/php.ini" ]; then
  cp -p "/etc/php/${PHP_VER}/fpm/php.ini" "/etc/php/${PHP_VER}/fpm/php.ini.bak" 2>> /tmp/enginescript_install_errors.log
fi
if ! cp -f /usr/local/bin/enginescript/config/etc/php/php.ini "/etc/php/${PHP_VER}/fpm/php.ini" 2>> /tmp/enginescript_install_errors.log; then
  echo "Error: Failed to copy php.ini for PHP ${PHP_VER}" >&2
  exit 1
fi
sed -i "s|SEDPHPVER|${PHP_VER}|g" "/etc/php/${PHP_VER}/fpm/php.ini" 2>> /tmp/enginescript_install_errors.log

if [ -f "/etc/php/${PHP_VER}/fpm/php-fpm.conf" ]; then
  cp -p "/etc/php/${PHP_VER}/fpm/php-fpm.conf" "/etc/php/${PHP_VER}/fpm/php-fpm.conf.bak" 2>> /tmp/enginescript_install_errors.log
fi
if ! cp -f /usr/local/bin/enginescript/config/etc/php/php-fpm.conf "/etc/php/${PHP_VER}/fpm/php-fpm.conf" 2>> /tmp/enginescript_install_errors.log; then
  echo "Error: Failed to copy php-fpm.conf for PHP ${PHP_VER}" >&2
  exit 1
fi
sed -i "s|SEDPHPVER|${PHP_VER}|g" "/etc/php/${PHP_VER}/fpm/php-fpm.conf" 2>> /tmp/enginescript_install_errors.log

if [ -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ]; then
  cp -p "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf.bak" 2>> /tmp/enginescript_install_errors.log
fi
if ! cp -f /usr/local/bin/enginescript/config/etc/php/www.conf "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" 2>> /tmp/enginescript_install_errors.log; then
  echo "Error: Failed to copy www.conf for PHP ${PHP_VER}" >&2
  exit 1
fi
sed -i "s|SEDPHPVER|${PHP_VER}|g" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" 2>> /tmp/enginescript_install_errors.log

# Tune PHP Configuration
apply_php_tuning

# Test the new configuration; keep the previous one if it fails
if command -v "php-fpm${PHP_VER}" > /dev/null 2>&1 && ! "php-fpm${PHP_VER}" -t > /dev/null 2>> /tmp/enginescript_install_errors.log; then
  echo "Error: php-fpm${PHP_VER} -t failed with the new configuration; restored the previous configuration files." >&2
  restore_php_configs
  print_last_errors
  exit 1
fi
print_last_errors
debug_pause "PHP Configuration Update"
