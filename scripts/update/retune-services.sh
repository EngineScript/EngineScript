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
#
# Re-tune services: works out the shared tuning plan for this server's current RAM and CPUs
# (enginescript-tuning.sh) and applies it to PHP-FPM, Redis, MariaDB, and Nginx without
# restarting a service. Each service's new configuration is tested first and kept only if it
# passes. Settings that need a restart (MariaDB's Aria cache and log buffer) take effect at the
# service's next restart. Run from the update menu, and by EngineScript updates when the plan
# is out of date (RAM or CPU count changed, or a new plan version).
#
# --benchmark: measure the database disk's write rate again (30 seconds of disk load while
# sites keep serving), for innodb_io_capacity. Without it, the saved result is reused.

if [[ "${1:-}" == "--benchmark" ]]; then
  tuning_benchmark_disk /var/lib/mysql
fi

if ! tuning_write_plan; then
  exit 1
fi
tuning_load

# Kept until every service has taken the plan, so the next EngineScript update tries again
TUNING_PENDING="${ES_TUNING_PENDING:-/etc/enginescript/tuning.pending}"
touch "${TUNING_PENDING}"

echo ""
echo "Tuning plan for $(tuning_get TUNING_MEM_MB) MB of RAM and $(tuning_get TUNING_CPUS) CPUs:"
echo "  PHP-FPM workers:   $(tuning_get PHP_MAX_CHILDREN) (memory_limit $(tuning_get PHP_MEMORY_LIMIT_MB)M)"
echo "  OPcache:           $(tuning_get OPCACHE_MEMORY_MB) MB ($(tuning_get OPCACHE_INTERNED_MB) MB strings, $(tuning_get OPCACHE_MAX_FILES) files)"
echo "  MariaDB:           buffer pool $(tuning_get MARIADB_BUFFER_POOL_MB) MB, $(tuning_get MARIADB_MAX_CONNECTIONS) connections"
echo "  Redis:             maxmemory $(tuning_get REDIS_MAXMEMORY_MB) MB"
echo "  Nginx cache:       index $(tuning_get NGINX_CACHE_ZONE_MB) MB, up to $(tuning_get NGINX_CACHE_MAX_MB) MB on disk"
echo "  Overrides:         ${ES_TUNING_OVERRIDES:-/etc/enginescript/tuning-overrides.conf} (KEY=value, optional)"
echo ""

RETUNE_FAILED=0

# PHP-FPM: rebuild php.ini, php-fpm.conf, and www.conf for each installed version; a graceful
# reload starts new workers with them (php-config-update.sh keeps the old files if php-fpm -t fails)
while IFS= read -r ver; do
  [[ -n "${ver}" ]] || continue
  if /usr/local/bin/enginescript/scripts/update/php-config-update.sh "${ver}"; then
    if systemctl is-active --quiet "php${ver}-fpm" && ! systemctl reload "php${ver}-fpm"; then
      echo "Error: PHP ${ver}-FPM did not reload; its new configuration applies at its next restart." >&2
      RETUNE_FAILED=1
    else
      echo "PHP ${ver}: applied the tuning plan."
    fi
  else
    RETUNE_FAILED=1
  fi
done < <(get_installed_php_versions)

# Redis: new redis.conf (tested in a throwaway instance), maxmemory and defrag applied live
if [[ -f /etc/redis/redis.conf ]]; then
  install_redis_service_override
  set_running_oom_score_adj redis-server -300
  apply_redis_tuning || RETUNE_FAILED=1
fi

# MariaDB: new my.cnf (checked with mariadbd), dynamic settings applied live
apply_mariadb_tuning || RETUNE_FAILED=1

# Nginx: cache sizes and connection settings patched in nginx.conf, tested, reloaded
apply_nginx_tuning || RETUNE_FAILED=1

print_last_errors
if [[ "${RETUNE_FAILED}" == "1" ]]; then
  echo "Re-tuning finished with errors (above); the services that failed kept their previous configuration." >&2
  echo "The next EngineScript update tries again." >&2
  exit 1
fi
rm -f "${TUNING_PENDING}"
echo "Re-tuning finished."
