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

source /etc/enginescript/install-state.conf
if [[ "${REDIS}" = 1 ]]; then
    echo "REDIS script has already run"
    exit 0
fi

# Install Redis (from Redis's repository, packages.redis.io, added by repositories-install.sh)
if ! apt install -qy redis redis-server redis-tools; then
  echo "Error: Installing Redis failed." >&2
  exit 1
fi

# EngineScript's redis.conf is written for Redis's own packages. If the Redis repository was not
# added (for example the key download failed), apt installs Ubuntu's older Redis instead; stop
# with a clear error rather than run a Redis that EngineScript did not set up for.
if ! apt-cache policy redis-server | awk '/^ \*\*\* /{getline; print; exit}' | grep -q 'packages\.redis\.io'; then
  echo "Error: Redis was not installed from Redis's repository (packages.redis.io)." >&2
  echo "Installed: $(dpkg-query -W -f='${Version}' redis-server 2> /dev/null). Check /etc/apt/sources.list.d/redis.list and the key in /usr/share/keyrings/redis-archive-keyring.gpg, then run the Redis install again." >&2
  exit 1
fi

# Copy Redis Config File
cp -rf /usr/local/bin/enginescript/config/etc/redis/redis.conf /etc/redis/redis.conf

# Redis Tuning: maxmemory from the shared tuning plan (enginescript-tuning.sh). Redis runs
# single-threaded (its default): a WordPress object cache's small requests over the local socket
# stay far below what one thread serves, and I/O threads would compete with PHP for CPU.
tuning_load
if [[ -z "$(tuning_get REDIS_MAXMEMORY_MB)" ]]; then
  tuning_write_plan || exit 1
  tuning_load
fi
sed -i "s|SEDREDISMAXMEM|$(tuning_get REDIS_MAXMEMORY_MB)|g" /etc/redis/redis.conf

# OOM killer order: PHP-FPM workers first, then Redis, then MariaDB
install_redis_service_override

# Add www-data to Redis Group
if ! getent group redis > /dev/null; then
  groupadd redis
fi
usermod -aG redis www-data

# Running PHP-FPM workers keep the groups they started with, so the Redis Object Cache plugin
# cannot reach the socket until PHP-FPM restarts. A reload starts new workers.
for fpm_unit in $(systemctl list-units --type=service --state=active --plain --no-legend 'php*-fpm.service' | awk '{print $1}'); do
  systemctl reload "${fpm_unit}"
done

# Finalize Redis Install
systemctl daemon-reload
restart_service "redis-server"
systemctl enable redis-server

sleep 3

# Permissions (after the restart: the Redis that stopped saved its data with group write)
set_redis_permissions

# Redis Service Check
verify_service_running "redis" "Redis"

# Mark the installation as complete
set_install_state "REDIS" "1"
echo "Redis completed successfully. Script done."
