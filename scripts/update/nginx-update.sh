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

# The build fingerprint that the automatic updates compare
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# Update flow:
#   1. Back up /etc/nginx and the current binary
#   2. Download and compile while the running Nginx keeps serving
#   3. Apply the new configuration (the running Nginx keeps its loaded configuration)
#   4. Test the new binary with the new configuration (nginx -t), and check that the PHP-FPM
#      socket it uses exists
#   5. Restart Nginx (about one second of downtime)
#   6. Verify that Nginx is running and answering, and that every site that reached PHP before
#      the update still does
#   7. On any failure in steps 4 to 6, restore the backup and keep or restart the previous version

ROLLBACK_DIR="/home/EngineScript/config-backups/nginx/pre-update"
FAILED_CONFIG_DIR="/etc/nginx.update-failed"

NGINX_WAS_RUNNING=0
if systemctl is-active --quiet nginx; then
  NGINX_WAS_RUNNING=1
fi

# Returns success when every site that reached PHP before the update still does, which
# confirms that Nginx reaches PHP-FPM. Sites that already failed (SITES_FAILING_BEFORE) are not
# held against the update.
sites_are_serving() {
  local attempt new_failures
  for attempt in 1 2 3; do
    new_failures="$(newly_failing_sites "${SITES_FAILING_BEFORE}" "$(get_sites_without_php)")"
    if [[ -z "${new_failures}" ]]; then
      return 0
    fi
    echo "Waiting for the sites to answer (attempt ${attempt} of 3)..."
    sleep 3
  done
  echo "These sites no longer work (HTTP 500, 502, 504, or no response):" >&2
  printf '  %s\n' "${new_failures//$'\n'/$'\n'  }" >&2
  return 1
}

# Returns success when Nginx is active and the default server answers on port 80
nginx_is_serving() {
  local attempt http_code
  for attempt in 1 2 3 4 5; do
    # A unit that failed to start, or is waiting to retry after a failed start
    # (Restart=on-failure), will not recover by waiting
    if systemctl is-failed --quiet nginx || [[ "$(systemctl show -p SubState --value nginx)" == "auto-restart" ]]; then
      return 1
    fi
    if systemctl is-active --quiet nginx; then
      http_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1/)"
      if [[ "${http_code}" =~ ^[23] ]]; then
        return 0
      fi
    fi
    echo "Waiting for Nginx to answer (attempt ${attempt} of 5)..."
    sleep 2
  done
  return 1
}

# Puts the saved binary back. Copy to a temporary name, then rename: writing directly over a
# running executable fails with "Text file busy", while a rename always succeeds.
restore_previous_binary() {
  cp -p "${ROLLBACK_DIR}/nginx" /usr/sbin/nginx.rollback \
    && mv -f /usr/sbin/nginx.rollback /usr/sbin/nginx \
    || echo "Error: Could not restore ${ROLLBACK_DIR}/nginx" >&2
}

# Puts back the configuration and binary saved in step 1. The failed configuration is kept
# in /etc/nginx.update-failed for troubleshooting.
restore_previous_nginx() {
  echo "Restoring the previous Nginx configuration and binary..."
  rm -rf "${FAILED_CONFIG_DIR}"
  mv /etc/nginx "${FAILED_CONFIG_DIR}"
  tar -xzf "${ROLLBACK_DIR}/etc-nginx.tar.gz" -C / || echo "Error: Could not extract ${ROLLBACK_DIR}/etc-nginx.tar.gz" >&2
  restore_previous_binary
  if [[ -f "${ROLLBACK_DIR}/nginx.service" ]]; then
    cp -p "${ROLLBACK_DIR}/nginx.service" /etc/systemd/system/nginx.service
    systemctl daemon-reload
  fi
  set_nginx_permissions
  echo "The failed configuration was kept in ${FAILED_CONFIG_DIR} for troubleshooting."
}

# One update at a time (the lock is shared with es.update and the other software updates)
acquire_lock "update" || exit 1

# Prompt for EngineScript Update. After it, run the new copy of this script: bash keeps running
# the text of the file it started with, and the shared functions sourced above are the old ones.
if [[ "${ES_ENGINESCRIPT_UPDATED:-0}" != "1" ]]; then
  if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> "${ES_STEP_ERROR_LOG}"
    ES_ENGINESCRIPT_UPDATED=1 exec bash /usr/local/bin/enginescript/scripts/update/nginx-update.sh "$@"
  else
    echo "Skipping EngineScript update."
  fi
fi

# Sites that do not reach PHP before the update (not held against it in step 6)
SITES_FAILING_BEFORE=""
if [[ "${NGINX_WAS_RUNNING}" == "1" ]]; then
  SITES_FAILING_BEFORE="$(get_sites_without_php)"
fi

# 1. Back up the current configuration and binary
echo "Backing up the current Nginx configuration and binary to ${ROLLBACK_DIR}..."
mkdir -p "${ROLLBACK_DIR}"
if ! tar -czf "${ROLLBACK_DIR}/etc-nginx.tar.gz" -C / etc/nginx || ! cp -p /usr/sbin/nginx "${ROLLBACK_DIR}/nginx"; then
  echo "Error: Could not back up the current Nginx. The update stopped; nothing was changed." >&2
  exit 1
fi
rm -f "${ROLLBACK_DIR}/nginx.service"
if [[ -f /etc/systemd/system/nginx.service ]]; then
  cp -p /etc/systemd/system/nginx.service "${ROLLBACK_DIR}/nginx.service"
fi
# Dated backup as well (kept for 15 days by nginx-backup.sh)
/usr/local/bin/enginescript/scripts/functions/backup/nginx-backup.sh 2>> "${ES_STEP_ERROR_LOG}"

# 2. Download and compile while the running Nginx keeps serving (nginx-build.sh is shared with
# the install, and fetches the OpenSSL, zlib, and PCRE2 versions in enginescript-variables.txt)
# The build runs at the lowest CPU and disk priority: the sites' Nginx, PHP, and MariaDB go
# first, and the build uses what they leave (it takes longer only while the server is busy)
LOW_PRIORITY=(nice -n 19)
if command -v ionice > /dev/null 2>&1 && ionice -c 3 true 2> /dev/null; then
  LOW_PRIORITY+=(ionice -c 3)
fi
if ! "${LOW_PRIORITY[@]}" /usr/local/bin/enginescript/scripts/install/nginx/nginx-build.sh; then
  # make install may have replaced the binary before failing; put the previous one back
  restore_previous_binary
  echo "Error: Building Nginx failed. The update stopped before changing any configuration." >&2
  echo "Nginx is still running the previous version. See /var/log/EngineScript/install-error-log.log." >&2
  exit 1
fi

# 3. Apply the new configuration. The running Nginx keeps its loaded configuration until the
# restart in step 5, and scripts called here must not reload it.
export ENGINESCRIPT_SKIP_NGINX_RELOAD=1
/usr/local/bin/enginescript/scripts/install/nginx/nginx-configure.sh || echo "Warning: A configuration step failed (see /var/log/EngineScript/install-error-log.log); the test in step 4 checks the result." >&2

# Assign Nginx Permissions
set_nginx_permissions

# Install the current systemd unit (takes effect with the restart in step 5)
cp -f /usr/local/bin/enginescript/config/etc/systemd/system/nginx.service /etc/systemd/system/nginx.service
chmod 644 /etc/systemd/system/nginx.service
systemctl daemon-reload

# 4. Test the new binary with the new configuration
echo "Testing the updated Nginx configuration..."
if ! /usr/sbin/nginx -t; then
  echo "ERROR: The updated Nginx configuration failed its test (nginx -t)." >&2
  restore_previous_nginx
  if [[ "${NGINX_WAS_RUNNING}" == "1" ]] && systemctl is-active --quiet nginx; then
    echo "Nginx kept running the previous version throughout; no restart was needed."
  else
    systemctl start nginx
  fi
  echo "The update was rolled back. Fix the error shown above and run the update again." >&2
  exit 1
fi

# nginx -t does not check that the PHP-FPM socket exists. A missing socket would make every
# PHP request fail (502) while Nginx itself runs.
PHP_SOCKET="$(get_nginx_php_socket)"
if [[ -z "${PHP_SOCKET}" || ! -S "${PHP_SOCKET}" ]]; then
  echo "ERROR: The updated configuration passes PHP requests to '${PHP_SOCKET:-(none found)}', which is not a PHP-FPM socket on this server." >&2
  echo "Installed PHP-FPM version: ${PHP_VER}. Check that PHP-FPM is running (systemctl status php${PHP_VER}-fpm)." >&2
  restore_previous_nginx
  if [[ "${NGINX_WAS_RUNNING}" == "1" ]] && systemctl is-active --quiet nginx; then
    echo "Nginx kept running the previous version throughout; no restart was needed."
  else
    systemctl start nginx
  fi
  echo "The update was rolled back." >&2
  exit 1
fi

# 5. Restart Nginx with the new binary and configuration
if [[ "${NGINX_WAS_RUNNING}" == "1" ]]; then
  systemctl restart nginx
else
  systemctl start nginx
fi

# 6. Verify, and roll back if Nginx is not running and answering, or a site does not reach PHP
if ! nginx_is_serving || ! sites_are_serving; then
  echo "ERROR: Nginx did not start correctly after the update, or a site did not answer." >&2
  systemctl status nginx --no-pager 2>&1 | tail -15
  restore_previous_nginx
  systemctl restart nginx
  if nginx_is_serving; then
    echo "The update was rolled back and the previous Nginx version is running." >&2
  else
    echo "CRITICAL: The previous Nginx version also failed to start. Check 'systemctl status nginx' and 'journalctl -u nginx'." >&2
  fi
  exit 1
fi

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -V
echo ""
echo "Nginx Executable Properties:"
checksec --format=json --file=/usr/sbin/nginx --extended | jq -r

echo "PASSED: Nginx is running."
set_install_state "NGINX" "1"

# What this Nginx was built from, so the automatic updates know the server is current
record_nginx_build_fingerprint
auto_update_clear "nginx"
