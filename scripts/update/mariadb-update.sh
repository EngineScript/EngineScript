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
# Update flow:
#   1. Back up every database (mariadb-dump), my.cnf, and EngineScript's systemd override
#   2. Upgrade the MariaDB packages (apt restarts MariaDB with the current configuration)
#   3. Prepare the new configuration in a staging file while MariaDB keeps running, and check
#      it (mariadbd --help --verbose rejects unknown options and invalid values)
#   4. Swap the new configuration in and restart MariaDB once
#   5. Verify that MariaDB answers and that every site that reached its database before the
#      update still does
#   6. On a failure in steps 3 to 5, restore the previous configuration and restart
# Package upgrades cannot be rolled back automatically; the dump from step 1 is kept for a
# manual restore.

ROLLBACK_DIR="/home/EngineScript/config-backups/mariadb/pre-update"
OVERRIDE_FILE="/etc/systemd/system/mariadb.service.d/enginescript-limits.conf"
STAGED_CONFIG="/etc/mysql/my.cnf.enginescript-new"

# Returns success when MariaDB answers a query over the local socket
mariadb_is_serving() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    # A unit that failed to start, or is waiting to retry after a failed start
    # (Restart=always in EngineScript's override), will not recover by waiting
    if systemctl is-failed --quiet mariadb || [[ "$(systemctl show -p SubState --value mariadb)" == "auto-restart" ]]; then
      return 1
    fi
    if mariadb --protocol=socket -N -e "SELECT 1" > /dev/null 2>&1; then
      return 0
    fi
    echo "Waiting for MariaDB to answer (attempt ${attempt} of 10)..."
    sleep 3
  done
  return 1
}

# Returns success when every site that reached its database before the update still does
sites_reach_database() {
  local new_failures
  new_failures="$(newly_failing_sites "${SITES_FAILING_BEFORE}" "$(get_sites_without_database)")"
  if [[ -n "${new_failures}" ]]; then
    echo "These sites can no longer reach their database:" >&2
    printf '  %s\n' "${new_failures//$'\n'/$'\n'  }" >&2
    return 1
  fi
  return 0
}

# Puts back the configuration saved in step 1 and restarts MariaDB
restore_previous_config() {
  echo "Restoring the previous MariaDB configuration..."
  cp -f "${ROLLBACK_DIR}/my.cnf" /etc/mysql/my.cnf
  if [[ -f "${ROLLBACK_DIR}/enginescript-limits.conf" ]]; then
    cp -p "${ROLLBACK_DIR}/enginescript-limits.conf" "${OVERRIDE_FILE}"
  fi
  rm -f "${STAGED_CONFIG}"
  systemctl daemon-reload
  systemctl restart mariadb
  if mariadb_is_serving; then
    echo "MariaDB is running with the previous configuration." >&2
  else
    echo "CRITICAL: MariaDB does not start with the previous configuration either. Check 'systemctl status mariadb' and /var/log/mysql/mysql-error.log." >&2
    echo "The databases were saved before the update in ${ROLLBACK_DIR}/all-databases.sql.gz." >&2
  fi
}

# Prompt for EngineScript Update. After it, run the new copy of this script: bash keeps running
# the text of the file it started with, and the shared functions sourced above are the old ones.
if [[ "${ES_ENGINESCRIPT_UPDATED:-0}" != "1" ]]; then
    if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
        /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
        print_last_errors
        debug_pause "EngineScript Update"
        ES_ENGINESCRIPT_UPDATED=1 exec bash /usr/local/bin/enginescript/scripts/update/mariadb-update.sh "$@"
    else
        echo "Skipping EngineScript update."
    fi
fi

if ! mariadb_is_serving; then
  echo "Error: MariaDB is not running. Start it and fix any problem before updating, so its databases can be backed up first." >&2
  exit 1
fi

# Sites that cannot reach their database before the update (not held against it in step 5)
SITES_FAILING_BEFORE="$(get_sites_without_database)"

# 1. Back up every database, my.cnf, and the systemd override
echo "Backing up all databases and the MariaDB configuration to ${ROLLBACK_DIR}..."
rm -rf "${ROLLBACK_DIR}"
mkdir -p "${ROLLBACK_DIR}"
chmod 700 "${ROLLBACK_DIR}"

# The compressed dump is smaller than the data directory, so require that much free space
DATADIR_KB="$(du -sk /var/lib/mysql 2> /dev/null | awk '{print $1}')"
FREE_KB="$(df -Pk "${ROLLBACK_DIR}" | awk 'NR==2 {print $4}')"
if [[ -n "${DATADIR_KB}" && -n "${FREE_KB}" && "${FREE_KB}" -lt "${DATADIR_KB}" ]]; then
  echo "Error: Not enough free disk space for the pre-update database backup (need about $((DATADIR_KB / 1024)) MB, $((FREE_KB / 1024)) MB free). The update stopped; nothing was changed." >&2
  exit 1
fi

if ! (set -o pipefail; mariadb-dump --all-databases --single-transaction --routines --events --triggers --hex-blob 2>> /tmp/enginescript_install_errors.log | gzip > "${ROLLBACK_DIR}/all-databases.sql.gz"); then
  print_last_errors
  echo "Error: Could not back up the databases. The update stopped; nothing was changed." >&2
  exit 1
fi
cp -p /etc/mysql/my.cnf "${ROLLBACK_DIR}/my.cnf"
if [[ -f "${OVERRIDE_FILE}" ]]; then
  cp -p "${OVERRIDE_FILE}" "${ROLLBACK_DIR}/enginescript-limits.conf"
fi
chmod 600 "${ROLLBACK_DIR}"/*
echo "Database backup: ${ROLLBACK_DIR}/all-databases.sql.gz ($(du -h "${ROLLBACK_DIR}/all-databases.sql.gz" | cut -f1))"

# Older installs replaced /etc/mysql/my.cnf, the MariaDB packages' link to
# /etc/mysql/mariadb.cnf, with a regular file, and left the untuned template (with SED
# placeholders) in mariadb.cnf. A package upgrade restores the link, so MariaDB would restart on
# that template. Put the current configuration into mariadb.cnf and restore the link first; the
# content MariaDB reads does not change.
if [[ -f /etc/mysql/my.cnf && ! -L /etc/mysql/my.cnf && -f /etc/mysql/mariadb.cnf ]]; then
  echo "Moving the MariaDB configuration back behind the package's /etc/mysql/my.cnf link..."
  cp -f /etc/mysql/my.cnf /etc/mysql/mariadb.cnf
  if [[ -L /etc/alternatives/my.cnf ]]; then
    ln -sfn /etc/alternatives/my.cnf /etc/mysql/my.cnf
  else
    ln -sfn /etc/mysql/mariadb.cnf /etc/mysql/my.cnf
  fi
fi

# 2. Upgrade the MariaDB packages. EngineScript's configuration replaces the packaged
# /etc/mysql/mariadb.cnf, so dpkg would ask whether to keep it (and fail without a terminal);
# --force-confold keeps it, and step 3 re-applies the current template anyway.
rm -f /etc/apt/sources.list.d/mariadb.list
curl -LsS --proto '=https' https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${MARIADB_VER}" --skip-maxscale 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Repository"

apt update --allow-releaseinfo-change -y 2>> /tmp/enginescript_install_errors.log
if ! sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold mariadb-server mariadb-client -y' 2>> /tmp/enginescript_install_errors.log; then
  print_last_errors
  echo "Error: The MariaDB package upgrade failed. The configuration was not changed." >&2
  if ! mariadb_is_serving; then
    systemctl start mariadb
  fi
  exit 1
fi
print_last_errors
debug_pause "MariaDB Installation"

if ! mariadb_is_serving; then
  systemctl start mariadb
  if ! mariadb_is_serving; then
    echo "CRITICAL: MariaDB does not run after the package upgrade (with the previous configuration). Check 'systemctl status mariadb' and /var/log/mysql/mysql-error.log." >&2
    echo "The databases were saved before the update in ${ROLLBACK_DIR}/all-databases.sql.gz." >&2
    exit 1
  fi
fi

# 3. Prepare and check the new configuration while MariaDB keeps running
cp -f /usr/local/bin/enginescript/config/etc/mysql/my.cnf "${STAGED_CONFIG}"
# Directory for secure_file_priv (my.cnf); MariaDB does not start without it
install -d -o mysql -g mysql -m 750 /var/lib/mysql-files
/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh "${STAGED_CONFIG}" 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Configuration"

CONFIG_PROBLEM=""
if grep -q 'SED[A-Z0-9]' "${STAGED_CONFIG}"; then
  CONFIG_PROBLEM="placeholders were not filled in: $(grep -o 'SED[A-Z0-9]*' "${STAGED_CONFIG}" | sort -u | tr '\n' ' ')"
else
  # Exits non-zero for unknown options; invalid values are reported as [ERROR] lines
  CHECK_OUTPUT="$(mariadbd --defaults-file="${STAGED_CONFIG}" --help --verbose 2>&1 > /dev/null)"
  CHECK_RC=$?
  if [[ "${CHECK_RC}" -ne 0 ]] || grep -q '\[ERROR\]' <<< "${CHECK_OUTPUT}"; then
    CONFIG_PROBLEM="$(grep -E '\[(ERROR|Warning)\]' <<< "${CHECK_OUTPUT}" | head -5)"
    CONFIG_PROBLEM="${CONFIG_PROBLEM:-mariadbd exited with ${CHECK_RC}}"
  fi
fi
if [[ -n "${CONFIG_PROBLEM}" ]]; then
  echo "ERROR: The new MariaDB configuration failed its check:" >&2
  printf '  %s\n' "${CONFIG_PROBLEM//$'\n'/$'\n'  }" >&2
  mv -f "${STAGED_CONFIG}" "${ROLLBACK_DIR}/my.cnf.failed"
  if [[ -f "${ROLLBACK_DIR}/enginescript-limits.conf" ]]; then
    cp -p "${ROLLBACK_DIR}/enginescript-limits.conf" "${OVERRIDE_FILE}"
    systemctl daemon-reload
  fi
  echo "The update kept the previous configuration (the failed one is in ${ROLLBACK_DIR}/my.cnf.failed). MariaDB was not restarted with it." >&2
  exit 1
fi

# 4. Swap the new configuration in and restart once. cp (like mariadb-install.sh) writes
# through /etc/mysql/my.cnf, which the MariaDB packages manage as a link to mariadb.cnf.
cp -f "${STAGED_CONFIG}" /etc/mysql/my.cnf
rm -f "${STAGED_CONFIG}"
systemctl daemon-reload

# 5. Verify, and restore the previous configuration on a failure
if ! systemctl restart mariadb || ! mariadb_is_serving || ! sites_reach_database; then
  echo "ERROR: MariaDB did not start correctly with the new configuration, or a site lost its database." >&2
  systemctl status mariadb --no-pager 2>&1 | tail -15
  restore_previous_config
  echo "The update restored the previous configuration. The MariaDB packages stay upgraded." >&2
  exit 1
fi
echo "PASSED: MariaDB is running with the new configuration."

# MariaDB Database Upgrade (system tables for the new version)
mariadb-upgrade --force 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Database Upgrade"

set_install_state "MARIADB" "1"

mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'
