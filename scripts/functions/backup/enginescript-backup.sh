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
# Backs up every site's database, wp-config.php, and wp-content, and EngineScript's own
# configuration; keeps them for the configured time; and optionally copies them to Amazon S3.
# Settings: the BACKUP_* options in /home/EngineScript/enginescript-install-options.txt.
#
# Usage: enginescript-backup.sh <mode>
#   scheduled        run by cron every hour at :05; does what the settings make due now
#                    (hourly database backups every hour, everything daily or weekly at 01:05)
#   now              back up everything immediately (es.backup)
#   database-hourly | database-daily | files | config
#                    one backup type immediately
#
# Layout (the same keys under s3://<bucket>/ when BACKUP_S3=1):
#   /home/EngineScript/site-backups/<site>/database/hourly/<YYYY-MM-DD-HH>/<site>-database.sql.gz
#   /home/EngineScript/site-backups/<site>/database/daily/<YYYY-MM-DD>/<site>-database.sql.gz
#                                                              and <site>-wp-config.php.gz
#   /home/EngineScript/site-backups/<site>/files/<YYYY-MM-DD>/<site>-wp-content.tar.gz
#   /home/EngineScript/config-backups/enginescript/<YYYY-MM-DD>/enginescript-config.tar.gz
#   S3 keys: <site>/backups/database/..., <site>/backups/files/..., enginescript-config/<date>/...
#
# Only dated folders are ever removed. Each step is checked; failures are logged to
# /var/log/EngineScript/enginescript-backup.log and make the script exit with 1.

resolve_backup_settings

MODE="${1:-scheduled}"
SITE_BACKUPS="/home/EngineScript/site-backups"
CONFIG_BACKUPS="/home/EngineScript/config-backups/enginescript"
LOG="/var/log/EngineScript/enginescript-backup.log"
AWS="${ES_BACKUP_AWS:-/usr/local/bin/aws}"
# ES_BACKUP_DATE, ES_BACKUP_HOUR, and ES_BACKUP_WEEKDAY are for testing the schedule
TODAY="${ES_BACKUP_DATE:-$(date +%Y-%m-%d)}"
HOUR="${ES_BACKUP_HOUR:-$(date +%H)}"
WEEKDAY="${ES_BACKUP_WEEKDAY:-$(date +%u)}"
FAILURES=0

# Backups hold every site's data and secrets: root only
umask 077
mkdir -p "$(dirname "${LOG}")" "${SITE_BACKUPS}" "${CONFIG_BACKUPS}"

log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${MODE}" "$*" | tee -a "${LOG}"
}

record_failure() {
  FAILURES=$((FAILURES + 1))
  log "ERROR: $*"
}

s3_enabled() {
  [[ "${BACKUP_S3}" == "1" && -n "${S3_BUCKET_NAME:-}" && "${S3_BUCKET_NAME}" != "PLACEHOLDER" ]]
}

# Copies a finished backup file to S3 under the same layout
# Usage: s3_upload <local file> <S3 key>
s3_upload() {
  s3_enabled || return 0
  if ! "${AWS}" s3 cp "$1" "s3://${S3_BUCKET_NAME}/$2" --storage-class STANDARD --only-show-errors >> "${LOG}" 2>&1; then
    record_failure "S3 upload failed: s3://${S3_BUCKET_NAME}/$2"
  fi
}

# Deletes the dated folders under an S3 prefix whose names sort before the cutoff. Only runs
# when BACKUP_S3_KEEP_DAYS is set, and only touches folders named like EngineScript's dates.
# Usage: s3_prune <prefix ending in /> <cutoff name>
s3_prune() {
  s3_enabled && [[ -n "${BACKUP_S3_KEEP_DAYS}" ]] || return 0
  local name
  while IFS= read -r name; do
    if [[ "${name}" < "$2" ]]; then
      "${AWS}" s3 rm "s3://${S3_BUCKET_NAME}/$1${name}/" --recursive --only-show-errors >> "${LOG}" 2>&1 \
        || record_failure "S3 cleanup failed: s3://${S3_BUCKET_NAME}/$1${name}/"
    fi
  done < <("${AWS}" s3 ls "s3://${S3_BUCKET_NAME}/$1" 2> /dev/null | awk '$1 == "PRE" {print $2}' | sed 's|/$||' \
    | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]{2})?$')
}

# Removes the folders directly inside a backup folder that are older than the given minutes
# Usage: prune_folders_older_than <folder> <minutes>
prune_folders_older_than() {
  if [[ -d "$1" ]]; then
    find "$1" -mindepth 1 -maxdepth 1 -type d -mmin "+$2" -exec rm -rf {} +
  fi
}

days_ago() {
  date -d "${TODAY} -$1 days" +%Y-%m-%d
}

load_sites() {
  SITES=()
  if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
    # shellcheck source=/dev/null
    source /home/EngineScript/sites-list/sites.sh
  fi
}

# Usage: backup_databases hourly|daily
backup_databases() {
  local kind="$1" stamp dir site site_root tmp file
  if [[ "${kind}" == "hourly" ]]; then
    stamp="${TODAY}-${HOUR}"
  else
    stamp="${TODAY}"
  fi
  for site in "${SITES[@]}"; do
    site_root="/var/www/sites/${site}/html"
    if [[ ! -f "${site_root}/wp-config.php" ]]; then
      log "Skipping the ${kind} database backup of ${site}: no WordPress in ${site_root}"
      continue
    fi
    dir="${SITE_BACKUPS}/${site}/database/${kind}/${stamp}"
    mkdir -p "${dir}"
    file="${dir}/${site}-database.sql.gz"
    tmp="${dir}/.${site}-database.sql.gz.partial"
    if (set -o pipefail; cd / && run_as_www_data wp db export - --path="${site_root}" --single-transaction --quick --add-drop-table 2>> "${LOG}" | gzip > "${tmp}"); then
      mv -f "${tmp}" "${file}"
      log "Database backup (${kind}): ${site}, $(du -h "${file}" | cut -f1)"
      s3_upload "${file}" "${site}/backups/database/${kind}/${stamp}/${site}-database.sql.gz"
    else
      rm -f "${tmp}"
      record_failure "Database backup (${kind}) failed: ${site}"
    fi

    if [[ "${kind}" == "daily" ]]; then
      if gzip -c "${site_root}/wp-config.php" > "${dir}/${site}-wp-config.php.gz"; then
        s3_upload "${dir}/${site}-wp-config.php.gz" "${site}/backups/database/daily/${stamp}/${site}-wp-config.php.gz"
      else
        record_failure "wp-config.php backup failed: ${site}"
      fi
      prune_folders_older_than "${SITE_BACKUPS}/${site}/database/daily" "$((BACKUP_DATABASE_KEEP_DAYS * 1440))"
      s3_prune "${site}/backups/database/daily/" "$(days_ago "${BACKUP_S3_KEEP_DAYS:-0}")"
    else
      # Hourly backups are kept for 2 days
      prune_folders_older_than "${SITE_BACKUPS}/${site}/database/hourly" 2880
      s3_prune "${site}/backups/database/hourly/" "$(date -d "${TODAY} ${HOUR}:00 -48 hours" +%Y-%m-%d-%H)"
    fi
  done
}

backup_files() {
  local site site_root dir tmp file rc
  for site in "${SITES[@]}"; do
    site_root="/var/www/sites/${site}/html"
    if [[ ! -d "${site_root}/wp-content" ]]; then
      log "Skipping the files backup of ${site}: no ${site_root}/wp-content"
      continue
    fi
    dir="${SITE_BACKUPS}/${site}/files/${TODAY}"
    mkdir -p "${dir}"
    file="${dir}/${site}-wp-content.tar.gz"
    tmp="${dir}/.${site}-wp-content.tar.gz.partial"
    tar -C "${site_root}" -czf "${tmp}" wp-content 2>> "${LOG}"
    rc=$?
    # GNU tar exits with 1 when a file changed while it was read; the archive is still usable
    if [[ "${rc}" -le 1 ]]; then
      mv -f "${tmp}" "${file}"
      [[ "${rc}" -eq 1 ]] && log "Note: files changed while ${site}'s wp-content was archived."
      log "Files backup: ${site}, $(du -h "${file}" | cut -f1)"
      s3_upload "${file}" "${site}/backups/files/${TODAY}/${site}-wp-content.tar.gz"
    else
      rm -f "${tmp}"
      # Removed only if empty: an earlier run today may have saved an archive here
      rmdir "${dir}" 2> /dev/null
      record_failure "Files backup failed: ${site} (tar exit ${rc})"
    fi
    prune_file_backups "${site}"
    s3_prune "${site}/backups/files/" "$(days_ago "${BACKUP_S3_KEEP_DAYS:-0}")"
  done
}

# Keeps a site's newest BACKUP_FILES_KEEP_COPIES files backups. Only dated folders that hold a
# finished archive count as copies; folders without one (left by a failed or interrupted run)
# are removed, so failed runs never push good backups out.
# Usage: prune_file_backups <site>
prune_file_backups() {
  local site="$1" base name excess i
  local -a complete=()
  base="${SITE_BACKUPS}/${site}/files"
  [[ -d "${base}" ]] || return 0
  while IFS= read -r name; do
    if [[ -f "${base}/${name}/${site}-wp-content.tar.gz" ]]; then
      complete+=("${name}")
    else
      rm -rf "${base:?}/${name}"
    fi
  done < <(find "${base}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort)
  excess=$((${#complete[@]} - BACKUP_FILES_KEEP_COPIES))
  for ((i = 0; i < excess; i++)); do
    rm -rf "${base:?}/${complete[i]}"
  done
}

# EngineScript's own configuration: install options, site list, database credentials,
# acme.sh account and certificates, install state, and root's crontab
backup_config() {
  local dir="${CONFIG_BACKUPS}/${TODAY}"
  local file="${dir}/enginescript-config.tar.gz"
  local tmp="${dir}/.enginescript-config.tar.gz.partial"
  local items=() item
  mkdir -p "${dir}"
  crontab -l > "${dir}/root-crontab.txt" 2> /dev/null || : > "${dir}/root-crontab.txt"
  for item in home/EngineScript/enginescript-install-options.txt home/EngineScript/sites-list \
      home/EngineScript/mysql-credentials root/.acme.sh etc/enginescript; do
    if [[ -e "/${item}" ]]; then
      items+=("${item}")
    fi
  done
  if tar -C / -czf "${tmp}" --exclude='root/.acme.sh/acme.sh.log' "${items[@]}" \
      -C "${dir}" root-crontab.txt 2>> "${LOG}"; then
    mv -f "${tmp}" "${file}"
    log "Configuration backup: $(du -h "${file}" | cut -f1)"
    if [[ "${BACKUP_S3_INCLUDE_CONFIG}" == "1" ]]; then
      s3_upload "${file}" "enginescript-config/${TODAY}/enginescript-config.tar.gz"
    fi
  else
    rm -f "${tmp}"
    record_failure "Configuration backup failed"
  fi
  rm -f "${dir}/root-crontab.txt"
  prune_folders_older_than "${CONFIG_BACKUPS}" "$((BACKUP_CONFIG_KEEP_DAYS * 1440))"
  if [[ "${BACKUP_S3_INCLUDE_CONFIG}" == "1" ]]; then
    s3_prune "enginescript-config/" "$(days_ago "${BACKUP_S3_KEEP_DAYS:-0}")"
  fi
}

# Folders from the layout older EngineScript versions used (wp-config/, wp-content/, nginx/,
# ssl-keys/, wp-uploads/, and loose files in database/daily) are no longer written. Their files
# are removed once they are older than BACKUP_DATABASE_KEEP_DAYS.
cleanup_old_layout() {
  local site folder base minutes="$((BACKUP_DATABASE_KEEP_DAYS * 1440))"
  for site in "${SITES[@]}"; do
    base="${SITE_BACKUPS}/${site}"
    for folder in wp-config wp-content nginx ssl-keys wp-uploads; do
      if [[ -d "${base}/${folder}" ]]; then
        find "${base}/${folder}" -type f -mmin "+${minutes}" -delete
        find "${base}/${folder}" -mindepth 1 -type d -empty -delete
      fi
    done
    if [[ -d "${base}/database/daily" ]]; then
      find "${base}/database/daily" -maxdepth 1 -type f -mmin "+${minutes}" -delete
    fi
  done
}

# One backup run at a time
exec 9> /run/enginescript-backup.lock
if ! flock -n 9; then
  log "Another backup run is still in progress; skipping this run."
  exit 0
fi

load_sites

case "${MODE}" in
  scheduled)
    if [[ "${BACKUP_DATABASE_FREQUENCY}" == "hourly" ]]; then
      backup_databases hourly
    fi
    if [[ "${HOUR}" == "01" ]]; then
      if [[ "${BACKUP_DATABASE_FREQUENCY}" != "off" ]]; then
        backup_databases daily
      fi
      if [[ "${BACKUP_FILES_FREQUENCY}" == "daily" ]] || [[ "${BACKUP_FILES_FREQUENCY}" == "weekly" && "${WEEKDAY}" == "7" ]]; then
        backup_files
      fi
      if [[ "${BACKUP_CONFIG_FREQUENCY}" == "daily" ]]; then
        backup_config
      fi
      cleanup_old_layout
    fi
    ;;
  now)
    backup_databases daily
    backup_files
    backup_config
    ;;
  database-hourly)
    backup_databases hourly
    ;;
  database-daily)
    backup_databases daily
    ;;
  files)
    backup_files
    ;;
  config)
    backup_config
    ;;
  *)
    echo "Usage: $0 scheduled|now|database-hourly|database-daily|files|config" >&2
    exit 2
    ;;
esac

if [[ "${FAILURES}" -gt 0 ]]; then
  log "Finished with ${FAILURES} failure(s)."
  exit 1
fi
exit 0
