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

# Source shared database credential functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# A staging copy of a WordPress site at staging.<domain>, for trying changes before making them
# on the live site.
#
# Usage: vhost-staging.sh create|refresh|delete <domain>
#   create   copy the live site's files and database to staging.<domain> and set it up
#   refresh  replace the staging copy's files and database with a new copy of the live site
#   delete   remove the staging copy: files, database, Nginx vhost, and Cloudflare DNS record
#
# The staging copy:
#   - is served from /var/www/sites/staging.<domain>/html, with its own database and user
#     (/home/EngineScript/staging-credentials/staging.<domain>.txt), its own Redis database and
#     key prefix, and the live site's certificate, which covers *.<domain>
#   - asks for the admin control panel's username and password (HTTP basic authentication),
#     sends no email, tells search engines not to index it, and skips the FastCGI page cache
#   - is not in sites.sh, so backups, cron jobs, and the all-domain tools leave it alone
#   - gets a proxied Cloudflare CNAME record, staging -> <domain>
# Each step is logged to /var/log/EngineScript/vhost-staging.log (without passwords).

ACTION="${1:-}"
DOMAIN="${2:-}"
STAGING="staging.${DOMAIN}"
LIVE_ROOT="/var/www/sites/${DOMAIN}/html"
STAGING_DIR="/var/www/sites/${STAGING}"
STAGING_ROOT="${STAGING_DIR}/html"
CREDENTIALS_DIR="/home/EngineScript/staging-credentials"
CREDENTIALS="${CREDENTIALS_DIR}/${STAGING}.txt"
VHOST="/etc/nginx/sites-enabled/${STAGING}.conf"
LOG_DIR="/var/log/domains/${STAGING}"
LOG="/var/log/EngineScript/vhost-staging.log"

log() {
  mkdir -p "$(dirname "${LOG}")"
  printf '%s [%s %s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${ACTION}" "${STAGING}" "$*" >> "${LOG}"
  echo "$*"
}

die() {
  log "Error: $*" >&2
  exit 1
}

# One value from a credentials file (KEY="value" lines), read without sourcing the file
read_credential() {
  sed -n "s/^$2=\"\(.*\)\"$/\1/p" "$1" 2> /dev/null | head -n 1
}

# WP-CLI on the staging copy, as www-data, without loading its plugins or theme
wp_staging() {
  (cd "${STAGING_ROOT}" && run_as_www_data wp "$@" --skip-plugins --skip-themes)
}

# Replace the value of a string constant in wp-config.php, and check that it took
# Usage: set_wp_config_string <wp-config.php> <constant> <value of letters, digits, and _ only>
set_wp_config_string() {
  sed -i "s|^\([[:space:]]*define([[:space:]]*['\"]$2['\"][[:space:]]*,[[:space:]]*['\"]\)[^'\"]*\(['\"]\)|\1$3\2|" "$1"
  grep -Eq "^[[:space:]]*define\([[:space:]]*['\"]$2['\"][[:space:]]*,[[:space:]]*['\"]$3['\"]" "$1"
}


#----------------------------------------------------------------------------------
# Cloudflare: the staging CNAME record (skipped, with a note, when the API settings are not set)

cf_enabled() {
  [[ -n "${CF_GLOBAL_API_KEY:-}" && "${CF_GLOBAL_API_KEY}" != "PLACEHOLDER" \
    && -n "${CF_ACCOUNT_EMAIL:-}" && "${CF_ACCOUNT_EMAIL}" != "PLACEHOLDER" ]]
}

# Usage: cf_call <METHOD> <path after /client/v4> [JSON body]
cf_call() {
  local args=(-s --max-time 30 -X "$1" "https://api.cloudflare.com/client/v4$2"
    -H "Content-Type: application/json")
  if [[ -n "${3:-}" ]]; then
    args+=(--data "$3")
  fi
  cloudflare_curl "${args[@]}"
}

cf_succeeded() {
  grep -Eq '"success"[[:space:]]*:[[:space:]]*true' <<< "$1"
}

# Sets CF_ZONE_ID, and CF_RECORD_ID, CF_RECORD_TYPE, and CF_RECORD_CONTENT for staging.<domain>
# (empty when there is no record). Returns 1 when Cloudflare cannot be asked.
cf_find_record() {
  local response
  CF_ZONE_ID="" CF_RECORD_ID="" CF_RECORD_TYPE="" CF_RECORD_CONTENT=""
  cf_enabled || return 1
  CF_ZONE_ID="$(cf_call GET "/zones?name=${DOMAIN}&status=active" | grep -o '"id":"[a-zA-Z0-9]*"' | head -n 1 | cut -d'"' -f4)"
  [[ -n "${CF_ZONE_ID}" ]] || return 1
  response="$(cf_call GET "/zones/${CF_ZONE_ID}/dns_records?name=${STAGING}")"
  cf_succeeded "${response}" || return 1
  CF_RECORD_ID="$(grep -o '"id":"[^"]*' <<< "${response}" | head -n 1 | cut -d'"' -f4)"
  CF_RECORD_TYPE="$(grep -o '"type":"[^"]*' <<< "${response}" | head -n 1 | cut -d'"' -f4)"
  CF_RECORD_CONTENT="$(grep -o '"content":"[^"]*' <<< "${response}" | head -n 1 | cut -d'"' -f4)"
}

# True when the record is the one this script adds
cf_record_is_ours() {
  [[ "${CF_RECORD_TYPE}" == "CNAME" && "${CF_RECORD_CONTENT}" == "${DOMAIN}" ]]
}

add_dns_record() {
  local body
  if ! cf_find_record; then
    log "Warning: Could not reach Cloudflare for ${DOMAIN}. Add a proxied CNAME record there: ${STAGING} -> ${DOMAIN}"
    return 0
  fi
  if [[ -n "${CF_RECORD_ID}" ]]; then
    log "Cloudflare: the CNAME record ${STAGING} -> ${DOMAIN} is already there."
    return 0
  fi
  body="{\"type\": \"CNAME\", \"name\": \"staging\", \"content\": \"${DOMAIN}\", \"proxied\": true, \"ttl\": 1, \"comment\": \"EngineScript staging copy\"}"
  if cf_succeeded "$(cf_call POST "/zones/${CF_ZONE_ID}/dns_records" "${body}")"; then
    log "Cloudflare: added the proxied CNAME record ${STAGING} -> ${DOMAIN}."
  else
    log "Warning: Cloudflare did not add the record. Add a proxied CNAME record there: ${STAGING} -> ${DOMAIN}"
  fi
}

delete_dns_record() {
  if ! cf_find_record; then
    log "Warning: Could not reach Cloudflare for ${DOMAIN}. Delete the ${STAGING} DNS record there if it exists."
    return 0
  fi
  if [[ -z "${CF_RECORD_ID}" ]]; then
    return 0
  fi
  if ! cf_record_is_ours; then
    log "Cloudflare: left the ${STAGING} record (${CF_RECORD_TYPE} ${CF_RECORD_CONTENT}) alone: EngineScript did not add it."
    return 0
  fi
  if cf_succeeded "$(cf_call DELETE "/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}")"; then
    log "Cloudflare: deleted the CNAME record ${STAGING}."
  else
    log "Warning: Cloudflare did not delete the ${STAGING} record; delete it in the Cloudflare dashboard."
  fi
}


#----------------------------------------------------------------------------------
# Checks

check_live_site() {
  [[ "${DOMAIN}" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || die "Not a domain: ${DOMAIN}"
  grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh 2> /dev/null \
    || die "${DOMAIN} is not a site on this server (/home/EngineScript/sites-list/sites.sh)."
  [[ -f "${LIVE_ROOT}/wp-config.php" ]] || die "${DOMAIN} has no WordPress (${LIVE_ROOT}/wp-config.php)."
  LIVE_DB="$(read_credential "/home/EngineScript/mysql-credentials/${DOMAIN}.txt" DB)"
  validate_db_identifier "${LIVE_DB}" "${DOMAIN}" || die "No database name for ${DOMAIN} in /home/EngineScript/mysql-credentials/${DOMAIN}.txt."
  # The staging copy uses the live site's certificate, which must cover *.<domain>
  openssl x509 -noout -ext subjectAltName -in "/etc/nginx/ssl/${DOMAIN}/fullchain.pem" 2> /dev/null | grep -qF "DNS:*.${DOMAIN}" \
    || die "The certificate in /etc/nginx/ssl/${DOMAIN}/ does not cover *.${DOMAIN}; re-issue it first (Domain Configuration Tools)."
  [[ -f /etc/nginx/restricted-access/.htpasswd ]] \
    || die "There is no admin control panel password (/etc/nginx/restricted-access/.htpasswd), which the staging copy asks for."
}

# Room for a copy of the files and the database, with 512 MB to spare
check_disk_space() {
  local files_kb db_kb free_kb
  files_kb="$(du -sk --exclude="${LIVE_ROOT}/wp-content/cache" "${LIVE_ROOT}" | cut -f1)"
  db_kb="$(mariadb -N -B -e "SELECT COALESCE(ROUND(SUM(data_length + index_length) / 1024), 0) FROM information_schema.tables WHERE table_schema = '${LIVE_DB}'")"
  free_kb="$(df -Pk /var/www | awk 'NR == 2 { print $4 }')"
  if (( free_kb < files_kb + db_kb + 524288 )); then
    die "Not enough disk space: the copy needs about $(( (files_kb + db_kb) / 1024 )) MB plus 512 MB to spare, and $(( free_kb / 1024 )) MB is free."
  fi
}

staging_exists() {
  [[ -f "${CREDENTIALS}" || -f "${VHOST}" || -d "${STAGING_DIR}" ]]
}

load_staging_credentials() {
  STAGING_DB="$(read_credential "${CREDENTIALS}" DB)"
  STAGING_USER="$(read_credential "${CREDENTIALS}" USR)"
  STAGING_PASSWORD="$(read_credential "${CREDENTIALS}" PSWD)"
  validate_db_identifier "${STAGING_DB}" "${STAGING}" && [[ "${STAGING_USER}" =~ ^[A-Za-z0-9]+$ ]] \
    && [[ "${STAGING_PASSWORD}" =~ ^[A-Za-z0-9_]+$ ]]
}


#----------------------------------------------------------------------------------
# Setting up the copy

# The staging database and its user, with new random credentials
create_staging_database() {
  STAGING_DB="${LIVE_DB:0:60}_stg"
  validate_db_identifier "${STAGING_DB}" "${STAGING}" || return 1
  if [[ "$(mariadb -N -B -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '${STAGING_DB}'")" != "0" ]]; then
    log "Error: The database ${STAGING_DB} already exists." >&2
    return 1
  fi
  validate_install_credentials "${RAND_CHAR16}" "${RAND_CHAR32}" "${STAGING}" || return 1
  write_credentials_file "${CREDENTIALS_DIR}" "${STAGING}" "${STAGING_DB}" "${RAND_CHAR16}" "${RAND_CHAR32}"
  load_staging_credentials || return 1
  execute_install_sql "${STAGING_DB}" "${STAGING_USER}" "${STAGING_PASSWORD}" "${STAGING}" || return 1
  log "Created the database ${STAGING_DB} and its user."
}

create_staging_logs() {
  mkdir -p "${LOG_DIR}"
  touch "${LOG_DIR}/${STAGING}-wp-error.log" "${LOG_DIR}/${STAGING}-nginx-error.log"
  chown root:root "${LOG_DIR}"
  chmod 755 "${LOG_DIR}"
  chown www-data:adm "${LOG_DIR}/"*.log
  chmod 640 "${LOG_DIR}/"*.log
}

# The site vhost template for staging.<domain>, with the live site's certificate, basic
# authentication, a noindex header, and no FastCGI page cache. Rolled back if nginx -t fails.
create_staging_vhost() {
  local settings
  settings=$'\n  # Staging copy (vhost-staging.sh): the admin control panel\'s username and password,\n'
  settings+=$'  # no search engine indexing, and no FastCGI page cache ($skip_cache 1 below)\n'
  settings+=$'  auth_basic "Staging copy";\n'
  settings+=$'  auth_basic_user_file /etc/nginx/restricted-access/.htpasswd;\n'
  settings+=$'  add_header X-Robots-Tag "noindex, nofollow" always;'
  # shellcheck disable=SC2016 # $skip_cache is an Nginx variable
  sed -e "s|YOURDOMAIN|${STAGING}|g" \
      -e "s|^  server_name .*|  server_name ${STAGING};|" \
      -e "s|/etc/nginx/ssl/${STAGING}/|/etc/nginx/ssl/${DOMAIN}/|g" \
      -e 's|^  set \$skip_cache 0;|  set $skip_cache 1;|' \
      /usr/local/bin/enginescript/config/etc/nginx/sites-available/your-domain.conf \
    | awk -v settings="${settings}" '{ print } /^  server_name / { print settings }' > "${VHOST}"
  # shellcheck disable=SC2016 # $skip_cache is an Nginx variable
  if ! grep -q '^  auth_basic_user_file ' "${VHOST}" || ! grep -q '^  set \$skip_cache 1;' "${VHOST}"; then
    rm -f "${VHOST}"
    log "Error: Could not write ${VHOST} from the vhost template." >&2
    return 1
  fi
  sync_nginx_http3_config
  if ! nginx -t > /dev/null 2>&1; then
    rm -f "${VHOST}"
    log "Error: nginx -t failed with the staging vhost, so it was removed. Check with: nginx -t" >&2
    return 1
  fi
  systemctl reload nginx
  log "Added the Nginx vhost ${VHOST}."
}

# Copy the live site's files (without its page cache folder)
copy_files() {
  local status
  mkdir -p "${STAGING_ROOT}"
  tar -C "${LIVE_ROOT}" --exclude=./wp-content/cache -cf - . | tar -C "${STAGING_ROOT}" -xpf -
  status=("${PIPESTATUS[@]}")
  # GNU tar exits with 1 when a file changed while it was read; the copy is still usable
  if (( status[0] > 1 || status[1] != 0 )); then
    log "Error: Copying the files failed (tar exit ${status[0]} and ${status[1]})." >&2
    return 1
  fi
  log "Copied the files: $(du -sh "${STAGING_ROOT}" | cut -f1)."
}

# Point the copied wp-config.php at the staging database, URL, logs, and Redis keys
configure_wp_config() {
  local wp_config="${STAGING_ROOT}/wp-config.php" live="${DOMAIN//./\\.}"
  # www.<domain> first: the address of a site that kept www when it was imported
  sed -i -e "s|//www\\.${live}|//${STAGING}|g" \
         -e "s|//${live}|//${STAGING}|g" \
         -e "s|/var/www/sites/${live}/|/var/www/sites/${STAGING}/|g" \
         -e "s|/var/log/domains/${live}/${live}-|/var/log/domains/${STAGING}/${STAGING}-|g" "${wp_config}"
  if ! set_wp_config_string "${wp_config}" DB_NAME "${STAGING_DB}" \
    || ! set_wp_config_string "${wp_config}" DB_USER "${STAGING_USER}" \
    || ! set_wp_config_string "${wp_config}" DB_PASSWORD "${STAGING_PASSWORD}"; then
    log "Error: Could not set the database settings in ${wp_config}." >&2
    return 1
  fi
  # Its own Redis key prefix and database, so the copy never reads or flushes the live site's cache
  wp_staging config set WP_REDIS_PREFIX "es_$(printf '%s' "${STAGING}" | sha256sum | cut -c1-12)" --type=constant --quiet || return 1
  assign_site_redis_database "${wp_config}" > /dev/null || log "Warning: The staging copy shares Redis database 0 (its keys still have their own prefix)."
  wp_staging config set WP_ENVIRONMENT_TYPE staging --type=constant --quiet || return 1
  log "Set up wp-config.php for the staging copy."
}

# Copy the live database, then change the live URL and paths to the staging ones
copy_database() {
  local from to
  if ! (set -o pipefail; mariadb-dump --single-transaction --quick "${LIVE_DB}" | mariadb "${STAGING_DB}"); then
    log "Error: Copying the database ${LIVE_DB} to ${STAGING_DB} failed." >&2
    return 1
  fi
  log "Copied the database ${LIVE_DB} to ${STAGING_DB}."
  # The URL as written in HTML and serialized data, the URL as escaped in JSON, and the file path.
  # www.<domain> first, the address of a site that kept www when it was imported: it moves to the
  # staging domain too, not to www.<staging domain>, which the certificate does not cover.
  for from in "//www.${DOMAIN}" "\\/\\/www.${DOMAIN}" "//${DOMAIN}" "\\/\\/${DOMAIN}" "/var/www/sites/${DOMAIN}/"; do
    if [[ "${from}" == *"www.${DOMAIN}" ]]; then
      to="${from%"www.${DOMAIN}"}${STAGING}"
    else
      to="${from/${DOMAIN}/${STAGING}}"
    fi
    wp_staging search-replace "${from}" "${to}" --all-tables-with-prefix --skip-columns=guid --report-changed-only || return 1
  done
}

# No email, no search engine indexing; the Nginx vhost adds the password and noindex header
apply_staging_safety() {
  wp_staging option update blog_public 0 --quiet || return 1
  mkdir -p "${STAGING_ROOT}/wp-content/mu-plugins"
  cat > "${STAGING_ROOT}/wp-content/mu-plugins/enginescript-staging.php" << 'EOF'
<?php
/**
 * Plugin Name: EngineScript Staging Copy
 * Description: This is a staging copy made by EngineScript (es.menu > Domain Configuration Tools). It sends no email.
 */

add_filter( 'pre_wp_mail', '__return_false' );
EOF
  printf 'User-agent: *\nDisallow: /\n' > "${STAGING_ROOT}/robots.txt"
  log "Turned off email and search engine indexing."
}

finish_copy() {
  set_www_data_tree "${STAGING_DIR}"
  chmod 600 "${STAGING_ROOT}/wp-config.php"
  flush_site_redis_cache "${STAGING_ROOT}/wp-config.php"
  if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    systemctl reload "php${PHP_VER}-fpm"
  fi
}

copy_live_site() {
  copy_files && configure_wp_config && copy_database && apply_staging_safety && finish_copy
}

print_summary() {
  echo ""
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "${BOLD}Staging copy:${NORMAL} https://${STAGING}"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "The browser asks for the admin control panel's username and password"
  echo "(ADMIN_CONTROL_PANEL_USERNAME and ADMIN_CONTROL_PANEL_PASSWORD in es.config). Then log in to"
  echo "WordPress with the live site's accounts."
  echo ""
  echo "It sends no email, search engines are told not to index it, and pages are not cached."
  echo "Backups and cron jobs skip it: scheduled WordPress tasks only run when you run them."
  echo "Database credentials: ${CREDENTIALS}"
  echo ""
}


#----------------------------------------------------------------------------------
# Actions

create_staging() {
  check_live_site
  if staging_exists; then
    die "${STAGING} already exists. Refresh it or delete it instead."
  fi
  if grep -Fxq "\"${STAGING}\"" /home/EngineScript/sites-list/sites.sh; then
    die "${STAGING} is already a site on this server."
  fi
  check_disk_space
  if cf_find_record && [[ -n "${CF_RECORD_ID}" ]] && ! cf_record_is_ours; then
    die "${STAGING} already has a DNS record in Cloudflare (${CF_RECORD_TYPE} ${CF_RECORD_CONTENT}); EngineScript does not replace it."
  fi
  log "Creating a staging copy of ${DOMAIN}..."
  if ! { create_staging_database && create_staging_logs && copy_live_site && create_staging_vhost; }; then
    log "Creating the staging copy failed; removing what was set up." >&2
    if staging_exists; then
      delete_staging > /dev/null
    fi
    exit 1
  fi
  add_dns_record
  log "Created the staging copy of ${DOMAIN}."
  print_summary
}

refresh_staging() {
  check_live_site
  [[ -f "${CREDENTIALS}" && -f "${VHOST}" ]] || die "${DOMAIN} has no staging copy to refresh. Create one first."
  load_staging_credentials || die "Could not read the staging database credentials in ${CREDENTIALS}."
  check_disk_space
  log "Refreshing the staging copy of ${DOMAIN}..."
  flush_site_redis_cache "${STAGING_ROOT}/wp-config.php"
  # The user's privileges on the database stay in place when it is dropped and created again
  if ! mariadb -e "DROP DATABASE IF EXISTS \`${STAGING_DB}\`; CREATE DATABASE \`${STAGING_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;"; then
    die "Could not empty the staging database ${STAGING_DB}."
  fi
  rm -rf "${STAGING_ROOT:?}"
  copy_live_site || die "Refreshing the staging copy failed. Refresh it again, or delete it."
  log "Refreshed the staging copy of ${DOMAIN}."
  print_summary
}

delete_staging() {
  [[ "${DOMAIN}" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || die "Not a domain: ${DOMAIN}"
  staging_exists || die "${DOMAIN} has no staging copy."
  log "Deleting the staging copy of ${DOMAIN}..."
  flush_site_redis_cache "${STAGING_ROOT}/wp-config.php"
  if [[ -f "${CREDENTIALS}" ]] && load_staging_credentials; then
    mariadb -e "DROP DATABASE IF EXISTS \`${STAGING_DB}\`; DROP USER IF EXISTS '${STAGING_USER}'@'localhost';" \
      || log "Warning: Could not drop the database ${STAGING_DB} or its user." >&2
  fi
  rm -f "${VHOST}"
  if nginx -t > /dev/null 2>&1; then
    systemctl reload nginx
  else
    log "Warning: nginx -t fails; Nginx was not reloaded. Check with: nginx -t" >&2
  fi
  rm -rf "${STAGING_DIR:?}" "${LOG_DIR:?}"
  rm -f "${CREDENTIALS}"
  if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
    systemctl reload "php${PHP_VER}-fpm"
  fi
  delete_dns_record
  log "Deleted the staging copy of ${DOMAIN}."
}

case "${ACTION}" in
  create) create_staging ;;
  refresh) refresh_staging ;;
  delete) delete_staging ;;
  *)
    echo "Usage: $0 create|refresh|delete <domain>" >&2
    exit 2
    ;;
esac
