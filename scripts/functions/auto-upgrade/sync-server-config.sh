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

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

#----------------------------------------------------------------------------------
# Start Main Script
#
# Settings that follow EngineScript's own files: when an update brings a different version of
# EngineScript, the server's copies are replaced with the current ones. The version last synced
# is kept in /var/lib/enginescript/synced-commit, and only a sync with no errors updates it, so a
# failed step runs again on the next update. Scheduled updates that fetched nothing new skip the
# sync; --force (a manual update) always runs it.

SYNCED_COMMIT_FILE="/var/lib/enginescript/synced-commit"
CURRENT_COMMIT="$(git -C /usr/local/bin/enginescript rev-parse HEAD 2> /dev/null)"

if [[ "${1:-}" != "--force" && -n "${CURRENT_COMMIT}" ]] \
  && [[ "$(cat "${SYNCED_COMMIT_FILE}" 2> /dev/null)" == "${CURRENT_COMMIT}" ]]; then
  echo "Server settings already match this version of EngineScript."
  exit 0
fi

failed=0

# Logs: root owns the log folder, and scheduled jobs' logs are rotated
set_enginescript_log_permissions 2>> /tmp/enginescript_install_errors.log || failed=1
install_enginescript_logrotate 2>> /tmp/enginescript_install_errors.log || failed=1
print_last_errors

# Cron: replace EngineScript's jobs with the current list. Jobs no longer on it are removed.
install_enginescript_cron 2>> /tmp/enginescript_install_errors.log || failed=1
print_last_errors

# Kernel settings: the audited sysctl file, applied live (a reboot completes the rest)
install_enginescript_sysctl 2>> /tmp/enginescript_install_errors.log || failed=1
print_last_errors

# Transparent Huge Pages: switched off before the services start
if [[ -f /etc/systemd/system/disable-thp.service ]]; then
  { cp -f /usr/local/bin/enginescript/config/etc/systemd/system/disable-thp.service /etc/systemd/system/disable-thp.service \
    && chmod 644 /etc/systemd/system/disable-thp.service \
    && systemctl daemon-reload; } 2>> /tmp/enginescript_install_errors.log || failed=1
  print_last_errors
fi

# Shared tuning plan: a new version can change the plan format, so re-tune right away instead of
# waiting for the daily check (daily-maintenance.sh), which also catches a resized droplet.
# retune-services.sh keeps its own retry marker, so it does not hold back the synced version.
if tuning_needs_replan; then
  echo "Re-tuning services for this server's RAM and CPUs..."
  /usr/local/bin/enginescript/scripts/update/retune-services.sh 2>> /tmp/enginescript_install_errors.log
  print_last_errors
fi

if [[ "${failed}" -eq 0 && -n "${CURRENT_COMMIT}" ]]; then
  mkdir -p "$(dirname "${SYNCED_COMMIT_FILE}")"
  echo "${CURRENT_COMMIT}" > "${SYNCED_COMMIT_FILE}"
fi
