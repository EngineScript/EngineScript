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

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

#----------------------------------------------------------------------------------
# Start Main Script
#
# Brings existing servers up to date with changes in this version. The updater
# (enginescript-update.sh) starts this script as a new process after fetching the new version,
# so it always runs the new code, even when the updater that started it is the previous
# version. Every step must be safe to run again on an already-updated server.

# Certificates of existing sites: reload Nginx after each renewal
migrate_acme_reload_commands 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP-FPM log: move existing installs back to the package default, which logrotate covers
migrate_php_fpm_log_path 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP: igbinary installed by name (Redis Object Cache's serializer), not only as a dependency
ensure_php_igbinary 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP: turn off session upload progress (security; WordPress does not use it)
migrate_php_upload_progress 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Backups: one scheduler cron job in place of the separate backup jobs
install_backup_cron 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Redis: 128 databases, and every site on its own database number
migrate_redis_databases 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Redis: cache flushes free memory in the background
migrate_redis_lazy_user_flush 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Kernel settings: the audited sysctl file, applied live (a reboot completes the rest)
install_enginescript_sysctl 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Kernel Samepage Merging: nothing on these servers can use it
disable_ksm 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Transparent Huge Pages: switched off before the services start
if [[ -f /etc/systemd/system/disable-thp.service ]]; then
  cp -f /usr/local/bin/enginescript/config/etc/systemd/system/disable-thp.service /etc/systemd/system/disable-thp.service
  chmod 644 /etc/systemd/system/disable-thp.service
  systemctl daemon-reload
fi

# Shared tuning plan: re-tune PHP-FPM, Redis, MariaDB, and Nginx when the server has no plan
# yet, the plan format changed, RAM or the CPU count changed (a resized droplet), or the last
# re-tune did not finish
if tuning_needs_replan; then
  echo "Re-tuning services for this server's RAM and CPUs..."
  /usr/local/bin/enginescript/scripts/update/retune-services.sh 2>> /tmp/enginescript_install_errors.log
  print_last_errors
fi

# Warn when the installed PHP version is no longer supported
INSTALLED_PHP_VER="$(get_installed_php_version)"
if [[ -n "${INSTALLED_PHP_VER}" ]] && ! printf '%s\n' "${SUPPORTED_PHP_VERSIONS[@]}" | grep -qxF "${INSTALLED_PHP_VER}"; then
  echo ""
  echo "WARNING: PHP ${INSTALLED_PHP_VER} is no longer supported by EngineScript (supported: ${SUPPORTED_PHP_VERSIONS[*]})."
  echo "Switch to a supported version with: es.menu > Update Software > Switch PHP Version"
  echo ""
fi

