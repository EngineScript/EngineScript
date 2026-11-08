#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }

#----------------------------------------------------------------------------------

# Start Main Script

echo -e "\nRestarting Services\n\n"

# Restart Nginx and PHP-FPM. The caches stay (es.cache clears them). Redis is only started when it
# is not running: restarting a working Redis would show Redis Object Cache's error page on every
# site while it starts, and empty every site's object cache.

# Test first: Nginx does not start again with a configuration that fails its test
if nginx -t; then
  restart_service "nginx"
else
  echo "Error: nginx -t failed, so Nginx was not restarted and keeps running. Fix the errors above first." >&2
fi
restart_php_fpm
if ! systemctl is-active --quiet redis-server; then
  echo "Redis is not running; starting it."
  systemctl start redis-server || echo "Error: Redis did not start. Check with: systemctl status redis-server" >&2
fi

echo "Done."
