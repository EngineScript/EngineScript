#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: One-Time Upgrades
#----------------------------------------------------------------------------------
# run_once must run a one-time upgrade only until it succeeds, record it in
# upgrades-done.conf (once, by its exact name), and leave a failed one unrecorded so the next
# update tries it again. Every name in normal-auto-upgrade.sh's ONE_TIME_UPGRADES must be a
# function in enginescript-upgrades.sh, or the upgrade would fail on every update.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export ENGINESCRIPT_UPGRADES_DONE_FILE="${WORK}/var/lib/enginescript/upgrades-done.conf"

source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"
# shellcheck source=scripts/functions/shared/enginescript-upgrades.sh
source "${REPO_ROOT}/scripts/functions/shared/enginescript-upgrades.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  echo "  PASSED: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo "  FAILED: $1" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Usage: check "<description>" "<actual>" "<expected>"
check() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (expected '$3', got '$2')"
  fi
}

RUNS=0
es_test_upgrade() { RUNS=$((RUNS + 1)); }
es_test_failing_upgrade() { RUNS=$((RUNS + 1)); return 1; }

echo "A new upgrade"
check "not done before it runs" "$(upgrade_is_done es_test_upgrade && echo recorded || echo missing)" "missing"
run_once es_test_upgrade
check "it runs" "${RUNS}" "1"
check "it is recorded" "$(cat "${ENGINESCRIPT_UPGRADES_DONE_FILE}")" "es_test_upgrade"
check "the record can be read by everyone, written by its owner" "$(stat -c %a "${ENGINESCRIPT_UPGRADES_DONE_FILE}")" "644"

echo "The same upgrade on the next update"
run_once es_test_upgrade
check "it does not run again" "${RUNS}" "1"
record_upgrade_done es_test_upgrade
check "recording it again adds no line" "$(wc -l < "${ENGINESCRIPT_UPGRADES_DONE_FILE}" | tr -d ' ')" "1"

echo "A failing upgrade"
RUNS=0
status=0
run_once es_test_failing_upgrade 2> "${WORK}/err.log" || status=$?
check "run_once reports the failure" "${status}" "1"
check "the error names the upgrade" "$(grep -c 'es_test_failing_upgrade did not finish' "${WORK}/err.log")" "1"
check "it is not recorded" "$(upgrade_is_done es_test_failing_upgrade && echo recorded || echo missing)" "missing"
run_once es_test_failing_upgrade 2> /dev/null || true
check "it runs again on the next update" "${RUNS}" "2"

echo "Names match exactly"
check "a longer name does not count" "$(upgrade_is_done es_test_upgrade_v2 && echo recorded || echo missing)" "missing"
check "a shorter name does not count" "$(upgrade_is_done es_test && echo recorded || echo missing)" "missing"

echo "normal-auto-upgrade.sh"
mapfile -t upgrades < <(sed -n '/^ONE_TIME_UPGRADES=(/,/^)/p' "${REPO_ROOT}/scripts/functions/auto-upgrade/normal-auto-upgrade.sh" \
  | sed -e '1d' -e '$d' -e '/^[[:space:]]*#/d' -e 's/[[:space:]]//g' -e '/^$/d')
check "lists one-time upgrades" "$([[ "${#upgrades[@]}" -gt 0 ]] && echo yes || echo no)" "yes"
for upgrade in "${upgrades[@]}"; do
  check "${upgrade} is a function" "$(declare -F "${upgrade}" > /dev/null && echo yes || echo no)" "yes"
done
check "no upgrade is listed twice" "$(printf '%s\n' "${upgrades[@]}" | sort | uniq -d | wc -l | tr -d ' ')" "0"

echo "remove_site_list_variable_sources"
# A site list from the old template, with two sites added
cat > "${WORK}/sites.sh" << 'EOF'
#!/usr/bin/env bash
# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Tasks to be performed on the following sites
SITES=(
"example.com"
"example.co.uk"
)
EOF
ES_SITES_LIST="${WORK}/sites.sh" remove_site_list_variable_sources
check "the variables and install options lines are gone" "$(grep -c 'enginescript-variables.txt\|enginescript-install-options.txt\|# EngineScript Variables' "${WORK}/sites.sh")" "0"
SITES=()
# shellcheck source=/dev/null
source "${WORK}/sites.sh"
check "the sites stay" "${SITES[*]}" "example.com example.co.uk"
ES_SITES_LIST="${WORK}/sites.sh" remove_site_list_variable_sources
check "running it again changes nothing" "$(grep -c '"example' "${WORK}/sites.sh")" "2"
ES_SITES_LIST="${WORK}/missing.sh" remove_site_list_variable_sources
check "a server without a site list is fine" "$?" "0"
SITES=()
# shellcheck source=/dev/null
source "${REPO_ROOT}/scripts/functions/cron/sites.sh"
check "the template only sets an empty SITES" "${#SITES[@]}:$(grep -c '^source' "${REPO_ROOT}/scripts/functions/cron/sites.sh")" "0:0"

echo "migrate_nginx_php_cache_control"
# The two files as the previous version installed them: the current ones without the fix
mkdir -p "${WORK}/nginx"
old_nginx_files() {
  local globals="${REPO_ROOT}/config/etc/nginx/globals"
  # shellcheck disable=SC2016  # an Nginx line, matched as text
  head -n "$(grep -n -x -F 'expires $expires;' "${globals}/map-expires.conf" | cut -d: -f1)" "${globals}/map-expires.conf" > "${WORK}/nginx/map-expires.conf"
  sed '/^# Keep the Cache-Control that WordPress sends/,/^$/d' "${globals}/php-fpm.conf" > "${WORK}/nginx/php-fpm.conf"
}
old_nginx_files
check "the old files have no fix" "$(cat "${WORK}/nginx/"*.conf | grep -c 'es_php_expires')" "0"
NGINX_T=0
RELOADS=0
nginx() { return "${NGINX_T}"; }
systemctl() { [[ "$1" == "reload" ]] && RELOADS=$((RELOADS + 1)); return 0; }
ES_NGINX_GLOBALS="${WORK}/nginx" migrate_nginx_php_cache_control > /dev/null
check "php-fpm.conf now matches the current file" \
  "$(diff -q "${WORK}/nginx/php-fpm.conf" "${REPO_ROOT}/config/etc/nginx/globals/php-fpm.conf" > /dev/null && echo same || echo different)" "same"
check "map-expires.conf now matches the current file" \
  "$(diff -q "${WORK}/nginx/map-expires.conf" "${REPO_ROOT}/config/etc/nginx/globals/map-expires.conf" > /dev/null && echo same || echo different)" "same"
check "Nginx reloads once" "${RELOADS}" "1"
check "no backup files are left" "$(find "${WORK}/nginx" -name '*.pre-cache-control' | wc -l | tr -d ' ')" "0"
ES_NGINX_GLOBALS="${WORK}/nginx" migrate_nginx_php_cache_control > /dev/null
check "running it again changes nothing" "$(grep -c 'es_php_expires' "${WORK}/nginx/php-fpm.conf"):${RELOADS}" "1:1"
old_nginx_files
cp "${WORK}/nginx/php-fpm.conf" "${WORK}/php-fpm.conf.before"
NGINX_T=1
status=0
ES_NGINX_GLOBALS="${WORK}/nginx" migrate_nginx_php_cache_control > /dev/null 2>&1 || status=$?
check "a failed nginx -t reports the failure" "${status}" "1"
check "a failed nginx -t puts php-fpm.conf back" \
  "$(diff -q "${WORK}/nginx/php-fpm.conf" "${WORK}/php-fpm.conf.before" > /dev/null && echo same || echo different)" "same"
check "a failed nginx -t puts map-expires.conf back" "$(grep -c 'es_php_expires' "${WORK}/nginx/map-expires.conf")" "0"
check "a failed nginx -t does not reload Nginx" "${RELOADS}" "1"
unset -f nginx systemctl
ES_NGINX_GLOBALS="${WORK}/none" migrate_nginx_php_cache_control
check "a server without the files is fine" "$?" "0"

echo "install_fail2ban"
printf '#!/bin/bash\necho run >> "%s/f2b-runs"\n' "${WORK}" > "${WORK}/fail2ban.sh"
chmod +x "${WORK}/fail2ban.sh"
F2B_STATUS="unknown ok not-installed"
dpkg-query() { echo "${F2B_STATUS}"; }
ES_FAIL2BAN_SCRIPT="${WORK}/fail2ban.sh" install_fail2ban > /dev/null
check "a server without fail2ban runs the install script" "$(wc -l < "${WORK}/f2b-runs" | tr -d ' ')" "1"
F2B_STATUS="install ok installed"
ES_FAIL2BAN_SCRIPT="${WORK}/fail2ban.sh" install_fail2ban > /dev/null
check "a server with fail2ban is left alone" "$(wc -l < "${WORK}/f2b-runs" | tr -d ' ')" "1"
unset -f dpkg-query

echo "add_auto_update_options"
NOTES=0
notify_admin() { NOTES=$((NOTES + 1)); }
# An options file from before the automatic software updates
sed '/^## Automatic Software Updates/,/^AUTO_UPDATE_MARIADB=/d' "${REPO_ROOT}/config/home/enginescript-install-options.txt" > "${WORK}/options.txt"
chmod 600 "${WORK}/options.txt"
check "the old options file has none of the options" "$(grep -c '^AUTO_UPDATE_' "${WORK}/options.txt")" "0"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/options.txt" add_auto_update_options > /dev/null
check "the three options are added, switched on" "$(grep '^AUTO_UPDATE_' "${WORK}/options.txt" | tr '
' ' ')" "AUTO_UPDATE_NGINX=1 AUTO_UPDATE_PHP=1 AUTO_UPDATE_MARIADB=1 "
check "they follow ENGINESCRIPT_AUTO_UPDATE" "$(grep -A2 '^ENGINESCRIPT_AUTO_UPDATE=' "${WORK}/options.txt" | tail -n 1)" "## Automatic Software Updates (Recommended) ##"
check "the file still loads, with every other option" "$(bash -c 'source "$1" && echo "${ENGINESCRIPT_AUTO_UPDATE}${AUTO_UPDATE_PHP}${TEST_MODE}"' _ "${WORK}/options.txt")" "110"
check "the file keeps its mode" "$(stat -c %a "${WORK}/options.txt")" "600"
check "the admin gets one note" "${NOTES}" "1"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/options.txt" add_auto_update_options > /dev/null
check "running it again changes nothing" "$(grep -c '^AUTO_UPDATE_' "${WORK}/options.txt"):${NOTES}" "3:1"
sed -i -e '/^AUTO_UPDATE_PHP=/d' -e 's/^AUTO_UPDATE_MARIADB=1/AUTO_UPDATE_MARIADB=0/' "${WORK}/options.txt"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/options.txt" add_auto_update_options > /dev/null
check "a missing option is added, and one the admin switched off stays off"   "$(grep -c '^AUTO_UPDATE_NGINX=1$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_PHP=1$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_MARIADB=0$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_MARIADB=1$' "${WORK}/options.txt")" "1110"
printf 'DEBUG_INSTALL=0
' > "${WORK}/short-options.txt"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/short-options.txt" add_auto_update_options > /dev/null
check "a file without ENGINESCRIPT_AUTO_UPDATE gets them at the end" "$(tail -n 1 "${WORK}/short-options.txt")" "AUTO_UPDATE_MARIADB=1"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/missing.txt" add_auto_update_options
check "a server without an options file is fine" "$?" "0"
unset -f notify_admin

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
