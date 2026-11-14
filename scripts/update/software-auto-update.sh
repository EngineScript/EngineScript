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

# The automatic update decisions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# Installs the software releases in enginescript-variables.txt on servers that have the
# AUTO_UPDATE_* install options on. The scheduled EngineScript update (enginescript-update.sh
# --scheduled) starts this script at its end, so it always works from the versions just fetched.
#
# For each part, in turn:
#   1. Skip it when its option is off, or the maintainer paused it (AUTO_UPDATE_PAUSED)
#   2. Skip it when the server already has the release
#   3. A release seen for the first time waits AUTO_UPDATE_DELAY_DAYS days (auto_update_due)
#   4. Run the part's update script, which backs up, checks, and rolls back by itself
#   5. Send the admin a note with the result (Pushbullet, when a token is set)
# A failed update stops the run: the remaining parts wait for the next day. Changes that are
# never automatic (a newer PHP version, a newer MariaDB series) get one note each instead.

# One update at a time (the scheduled EngineScript update that starts this script holds the lock)
acquire_lock "update" || exit 1

# Not on an unfinished install
require_installation_complete "Automatic software updates"

if [[ "${ENGINESCRIPT_AUTO_UPDATE}" != "1" ]]; then
  echo "ENGINESCRIPT_AUTO_UPDATE is off: no automatic software updates."
  exit 0
fi
resolve_auto_update_settings

# Usage: update_part <part> "<label>" <target function> "<description>" <update script> [arguments]
# The target function prints the release to install, or nothing when the server already has it;
# it runs again after the update, which has worked only when it then prints nothing. Returns 1
# only when the update failed.
update_part() {
  local part="$1" label="$2" target="$3" description="$4" release reason
  shift 4
  release="$("${target}")"

  if [[ -z "${release}" ]]; then
    echo "${label}: up to date."
    return 0
  fi
  if ! reason="$(auto_update_due "${part}" "${release}")"; then
    echo "${label}: ${description} is available; ${reason}"
    return 0
  fi

  echo "${label}: installing ${description}..."
  # ES_ENGINESCRIPT_UPDATED: EngineScript was updated just now, so the script does not ask
  if ES_ENGINESCRIPT_UPDATED=1 bash "$@" && [[ "$("${target}" 2> /dev/null)" != "${release}" ]]; then
    echo "${label}: updated to ${description}."
    auto_update_clear "${part}"
    auto_update_record_last "${part}" "updated" "${description}"
    notify_admin "Server: ${IP_ADDRESS}" "EngineScript updated ${label} automatically: ${description}."
    return 0
  fi

  echo "${label}: the automatic update to ${description} failed, or the server does not have it afterwards." >&2
  auto_update_record_failed "${part}" "${release}"
  auto_update_record_last "${part}" "failed" "${description}"
  notify_admin "Server: ${IP_ADDRESS}" "EngineScript's automatic ${label} update (${description}) failed. The update script restores the previous setup where it can; check that your sites work. Log: /var/log/EngineScript/cron-software-auto-update.log. It is not tried again automatically: run it from es.menu > Update Software."
  return 1
}

# True when the part is switched on and not paused; otherwise says why it is skipped
part_is_on() {
  local part="$1" label="$2"

  if ! auto_update_enabled "${part}"; then
    echo "${label}: automatic updates are off (AUTO_UPDATE_${part^^}=0)."
    return 1
  fi
  if auto_update_paused "${part}"; then
    echo "${label}: automatic updates are paused by EngineScript for now."
    return 1
  fi
  return 0
}

# Nginx: rebuilt when Nginx or anything compiled into it has a new version
if part_is_on "nginx" "Nginx"; then
  update_part "nginx" "Nginx" nginx_auto_update_target "Nginx ${NGINX_VER} (OpenSSL ${OPENSSL_VER}, PCRE2 ${PCRE2_VER})" \
    /usr/local/bin/enginescript/scripts/update/nginx-update.sh || exit 1
fi

# PHP: the tested patch release of the installed version (php_auto_update_target)
INSTALLED_PHP="$(get_installed_php_version)"
if [[ -n "${INSTALLED_PHP}" ]]; then
  NEWER_PHP="$(php_newer_version "${INSTALLED_PHP}")"
  if [[ -n "${NEWER_PHP}" ]]; then
    auto_update_notice_once "php-version" "${NEWER_PHP}" \
      "EngineScript now supports PHP ${NEWER_PHP}. This server runs PHP ${INSTALLED_PHP}, which keeps getting patch releases. Switching is never automatic: check that your plugins and themes support PHP ${NEWER_PHP}, then use es.menu > Update Software > Switch PHP Version."
  fi
  if part_is_on "php" "PHP"; then
    apt-get update --allow-releaseinfo-change -y > /dev/null 2>&1
    php_target() { php_auto_update_target "${INSTALLED_PHP}"; }
    PHP_TARGET="$(php_target 2> /dev/null)"
    update_part "php" "PHP" php_target "PHP ${PHP_TARGET:-${INSTALLED_PHP}}" \
      /usr/local/bin/enginescript/scripts/update/php-patch-update.sh --build "${PHP_TARGET}" || exit 1
  fi
fi

# MariaDB: a newer patch release of the installed series (mariadb_auto_update_target)
NEWER_MARIADB="$(mariadb_newer_series)"
if [[ -n "${NEWER_MARIADB}" ]]; then
  auto_update_notice_once "mariadb-series" "${NEWER_MARIADB%.*}" \
    "EngineScript now installs MariaDB ${NEWER_MARIADB%.*}. This server runs MariaDB $(mariadb_installed_version), which is not moved to a new series automatically. When you are ready, use es.menu > Update Software > Update MariaDB (every database is backed up first)."
fi
if part_is_on "mariadb" "MariaDB"; then
  MARIADB_TARGET="$(mariadb_auto_update_target)"
  # Not while a backup runs: both dump every database. A backup that starts during the update
  # skips its run, and the update's own dump covers it.
  if [[ -n "${MARIADB_TARGET}" ]] && ! acquire_lock "backup" 2> /dev/null; then
    echo "MariaDB: a backup is running; the update waits for the next day."
  else
    update_part "mariadb" "MariaDB" mariadb_auto_update_target "MariaDB ${MARIADB_VER}" \
      /usr/local/bin/enginescript/scripts/update/mariadb-update.sh || exit 1
  fi
fi
