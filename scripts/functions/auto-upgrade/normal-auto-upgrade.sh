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

# The one-time upgrades
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-upgrades.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-upgrades.sh" >&2; exit 1; }

#----------------------------------------------------------------------------------
# Start Main Script
#
# One-time upgrades: bring a server installed by an earlier version up to the current setup.
# Each runs once per server and is recorded in /var/lib/enginescript/upgrades-done.conf when it
# succeeds (run_once); one that fails runs again on the next update, so each must still be safe
# to run again. New installs record them all as done (--record-all) without running them.
#
# The updater (enginescript-update.sh) starts this script as a new process after fetching the
# new version, so it always runs the new code. Settings that follow every EngineScript change
# (cron jobs, logrotate, kernel settings) are in sync-server-config.sh instead.

ONE_TIME_UPGRADES=(
  # Certificates of existing sites: reload Nginx after each renewal
  migrate_acme_reload_commands
  # PHP-FPM log: move existing installs back to the package default, which logrotate covers
  migrate_php_fpm_log_path
  # PHP: igbinary installed by name (Redis Object Cache's serializer), not only as a dependency
  ensure_php_igbinary
  # PHP: turn off session upload progress (security; WordPress does not use it)
  migrate_php_upload_progress
  # Redis: 128 databases, and every site on its own database number
  migrate_redis_databases
  # Redis: cache flushes free memory in the background
  migrate_redis_lazy_user_flush
  # Kernel Samepage Merging: nothing on these servers can use it
  disable_ksm
  # Import: the empty folders of the old import format
  remove_old_import_folders
  # Site list: no longer loads the variables and install options itself
  remove_site_list_variable_sources
)

if [[ "${1:-}" == "--record-all" ]]; then
  for upgrade in "${ONE_TIME_UPGRADES[@]}"; do
    record_upgrade_done "${upgrade}"
  done
  exit 0
fi

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

for upgrade in "${ONE_TIME_UPGRADES[@]}"; do
  run_once "${upgrade}" 2>> "${ES_STEP_ERROR_LOG}"
  print_last_errors
done
