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
# dpkg-query's status of an installed package
INSTALLED="install ok installed"
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
check "a server without a site list is fine, and gets none" "$?:$([[ -e "${WORK}/missing.sh" ]] && echo created || echo absent)" "0:absent"
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
check "a server without the files is fine, and gets none" "$?:$([[ -e "${WORK}/none" ]] && echo created || echo absent)" "0:absent"

echo "install_fail2ban"
printf '#!/bin/bash\necho run >> "%s/f2b-runs"\n' "${WORK}" > "${WORK}/fail2ban.sh"
chmod +x "${WORK}/fail2ban.sh"
F2B_STATUS="unknown ok not-installed"
dpkg-query() { echo "${F2B_STATUS}"; }
ES_FAIL2BAN_SCRIPT="${WORK}/fail2ban.sh" install_fail2ban > /dev/null
check "a server without fail2ban runs the install script" "$(wc -l < "${WORK}/f2b-runs" | tr -d ' ')" "1"
F2B_STATUS="${INSTALLED}"
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
check "the three options are added, switched on" "$(grep '^AUTO_UPDATE_' "${WORK}/options.txt" | tr '\n' ' ')" "AUTO_UPDATE_NGINX=1 AUTO_UPDATE_PHP=1 AUTO_UPDATE_MARIADB=1 "
check "they follow ENGINESCRIPT_AUTO_UPDATE" "$(grep -A2 '^ENGINESCRIPT_AUTO_UPDATE=' "${WORK}/options.txt" | tail -n 1)" "## Automatic Software Updates (Recommended) ##"
check "the file still loads, with every other option" "$(bash -c 'source "$1" && echo "${ENGINESCRIPT_AUTO_UPDATE}${AUTO_UPDATE_PHP}${TEST_MODE}"' _ "${WORK}/options.txt")" "110"
check "the file keeps its mode" "$(stat -c %a "${WORK}/options.txt")" "600"
check "the admin gets one note" "${NOTES}" "1"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/options.txt" add_auto_update_options > /dev/null
check "running it again changes nothing" "$(grep -c '^AUTO_UPDATE_' "${WORK}/options.txt"):${NOTES}" "3:1"
sed -i -e '/^AUTO_UPDATE_PHP=/d' -e 's/^AUTO_UPDATE_MARIADB=1/AUTO_UPDATE_MARIADB=0/' "${WORK}/options.txt"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/options.txt" add_auto_update_options > /dev/null
check "a missing option is added, and one the admin switched off stays off" "$(grep -c '^AUTO_UPDATE_NGINX=1$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_PHP=1$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_MARIADB=0$' "${WORK}/options.txt")$(grep -c '^AUTO_UPDATE_MARIADB=1$' "${WORK}/options.txt")" "1110"
printf 'DEBUG_INSTALL=0\n' > "${WORK}/short-options.txt"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/short-options.txt" add_auto_update_options > /dev/null
check "a file without ENGINESCRIPT_AUTO_UPDATE gets them at the end" "$(tail -n 1 "${WORK}/short-options.txt")" "AUTO_UPDATE_MARIADB=1"
NOTES_BEFORE="${NOTES}"
ENGINESCRIPT_INSTALL_OPTIONS_FILE="${WORK}/missing.txt" add_auto_update_options
check "a server without an options file is fine, gets none, and sends no note" "$?:$([[ -e "${WORK}/missing.txt" ]] && echo created || echo absent):$((NOTES - NOTES_BEFORE))" "0:absent:0"
unset -f notify_admin

echo "add_missing_ppas (the weekly job)"
# shellcheck disable=SC2034  # read by add_missing_ppas
ENGINESCRIPT_PPAS=("ppa:example/one")
# shellcheck disable=SC2034
UBUNTU_VERSION="26.04"
# shellcheck disable=SC2034
UBUNTU_CODENAME="resolute"
PPA_ADDS=0
APT_FAILS=0
export ES_APT_RETRY_SECONDS=0
ppa_is_added() { return 1; }
add-apt-repository() { PPA_ADDS=$((PPA_ADDS + 1)); }
# apt-get runs in a command substitution, so its calls are counted in a file
apt-get() { echo call >> "${WORK}/apt-calls"; (( $(grep -c . "${WORK}/apt-calls") > APT_FAILS )); }
curl() { printf '%s' "${PPA_STATUS}"; }
apt_calls() { grep -c . "${WORK}/apt-calls" 2> /dev/null || true; }
PPA_STATUS=404
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "a PPA without packages yet: the log says so, and nothing is added" "$(cat "${WORK}/ppa.txt"):${PPA_ADDS}" \
  "ppa:example/one still has no packages for Ubuntu 26.04 (resolute); trying again next week.:0"
PPA_STATUS=000
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "no connection to Launchpad: the log says that, not 'no packages'" \
  "$(grep -c 'Could not ask Launchpad about ppa:example/one (HTTP status 000' "${WORK}/ppa.txt"):$(grep -c 'no packages' "${WORK}/ppa.txt"):${PPA_ADDS}" "1:0:0"
PPA_STATUS=503
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "a Launchpad error: the same, with its status" "$(grep -c 'HTTP status 503' "${WORK}/ppa.txt"):${PPA_ADDS}" "1:0"
PPA_STATUS=200
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "a PPA with packages is added and apt's lists are refreshed once" "${PPA_ADDS}:$(apt_calls):$(grep -c '^Added ppa:example/one' "${WORK}/ppa.txt")" "1:1:1"
rm -f "${WORK}/apt-calls"
APT_FAILS=2
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "apt busy twice: it tries again, without a warning" "$(apt_calls):$(grep -c 'Warning' "${WORK}/ppa.txt")" "3:0"
rm -f "${WORK}/apt-calls"
APT_FAILS=99
add_missing_ppas > "${WORK}/ppa.txt" 2>&1
check "apt busy throughout: six tries, a warning, and the job still succeeds" "$?:$(apt_calls):$(grep -c 'package lists were not refreshed' "${WORK}/ppa.txt")" "0:6:1"
unset -f ppa_is_added add-apt-repository apt-get curl apt_calls

echo "migrate_gcc_15_on_ubuntu_26_04"
cat > "${WORK}/gcc-install.sh" <<STUB
#!/bin/bash
echo gcc >> "${WORK}/gcc-calls"
exit "\${GCC_SCRIPT_STATUS:-0}"
STUB
chmod +x "${WORK}/gcc-install.sh"
export GCC_SCRIPT_STATUS=0
dpkg-query() { echo "${GCC16_STATUS}"; }
apt-get() { echo "apt-get $*" >> "${WORK}/gcc-calls"; }
gcc_calls() { cat "${WORK}/gcc-calls" 2> /dev/null | tr '\n' ';'; }
# Prints the upgrade's exit status and the commands it ran
run_gcc_upgrade() {
  local status=0
  rm -f "${WORK}/gcc-calls"
  UBUNTU_VERSION="$1" GCC16_STATUS="$2" ES_GCC_INSTALL_SCRIPT="${WORK}/gcc-install.sh" migrate_gcc_15_on_ubuntu_26_04 > /dev/null 2>&1 || status=$?
  echo "${status}:$(gcc_calls)"
}
check "24.04 keeps its compilers" "$(run_gcc_upgrade 24.04 "${INSTALLED}")" "0:"
check "26.04 without the GCC 16 snapshot is left alone" "$(run_gcc_upgrade 26.04 "")" "0:"
check "26.04 with the snapshot: GCC 15 is set up, then the snapshot is removed" "$(run_gcc_upgrade 26.04 "${INSTALLED}")" "0:gcc;apt-get remove --purge -y g++-16 gcc-16;"
check "a failed GCC 15 setup fails the upgrade and keeps the snapshot" "$(GCC_SCRIPT_STATUS=1 run_gcc_upgrade 26.04 "${INSTALLED}")" "1:gcc;"
unset -f dpkg-query apt-get gcc_calls run_gcc_upgrade

echo "remove_source_built_liburing"
LR="${WORK}/liburing-root"
mkdir -p "${LR}/usr/lib/pkgconfig" "${LR}/usr/include/liburing/io_uring" "${LR}/usr/man/man2" "${LR}/usr/man/man3" \
  "${LR}/usr/man/man7" "${LR}/usr/src/liburing-liburing-2.15" "${LR}/usr/lib/x86_64-linux-gnu"
touch "${LR}/usr/lib/liburing.so.2.15" "${LR}/usr/lib/liburing.a" "${LR}/usr/lib/liburing-ffi.so.2.15" \
  "${LR}/usr/lib/pkgconfig/liburing.pc" "${LR}/usr/lib/pkgconfig/zlib.pc" \
  "${LR}/usr/include/liburing.h" "${LR}/usr/include/liburing/io_uring.h" "${LR}/usr/include/liburing/io_uring/query.h" \
  "${LR}/usr/man/man2/io_uring_setup.2" "${LR}/usr/man/man3/IO_URING_VERSION_MAJOR.3" "${LR}/usr/man/man3/__io_uring_buf_ring_cq_advance.3" \
  "${LR}/usr/man/man7/io_uring.7" "${LR}/usr/lib/x86_64-linux-gnu/liburing.so.2.14"
ln -s liburing.so.2.15 "${LR}/usr/lib/liburing.so.2"
ln -s liburing.so.2.15 "${LR}/usr/lib/liburing.so"
# A header a package owns (liburing-dev) is kept
dpkg-query() {
  local option="$1" path="$2"
  [[ "${option}" == "-S" && "${path}" == "/usr/include/liburing/io_uring.h" ]]
}
ES_LIBURING_ROOT="${LR}" remove_source_built_liburing > /dev/null
check "the library, headers, pkg-config files, man pages, and sources are removed" \
  "$(find "${LR}" \( -type f -o -type l \) ! -path '*/x86_64-linux-gnu/*' | sed "s|${LR}||" | grep 'uring' | sort | tr '\n' ' ')" \
  "/usr/include/liburing/io_uring.h "
check "Ubuntu's liburing and other pkg-config files stay" \
  "$([[ -f "${LR}/usr/lib/x86_64-linux-gnu/liburing.so.2.14" && -f "${LR}/usr/lib/pkgconfig/zlib.pc" ]] && echo kept || echo removed)" "kept"
check "the emptied man folders are removed, and the folder with a kept header stays" \
  "$([[ -e "${LR}/usr/man" ]] && echo man-kept || echo man-removed):$([[ -d "${LR}/usr/include/liburing" ]] && echo include-kept || echo include-removed)" \
  "man-removed:include-kept"
ES_LIBURING_ROOT="${LR}" remove_source_built_liburing > /dev/null
check "running it again succeeds" "$?" "0"
unset -f dpkg-query

echo "remove_pipx_recommended_packages"
# Prints the upgrade's exit status and the apt-get commands it ran
run_mkdocs_upgrade() {
  local status=0
  rm -f "${WORK}/mkdocs-calls"
  MKDOCS_STATUS="$1" MKDOCS_AUTO="$2" remove_pipx_recommended_packages > /dev/null 2>&1 || status=$?
  echo "${status}:$(tr '\n' ';' 2> /dev/null < "${WORK}/mkdocs-calls")"
}
dpkg-query() { echo "${MKDOCS_STATUS}"; }
apt-mark() { [[ "${MKDOCS_AUTO}" == "auto" ]] && echo "mkdocs"; return 0; }
apt-get() { echo "apt-get $*" >> "${WORK}/mkdocs-calls"; }
check "without mkdocs, nothing is removed" "$(run_mkdocs_upgrade "" auto)" "0:"
check "mkdocs the admin installed is kept" "$(run_mkdocs_upgrade "${INSTALLED}" manual)" "0:"
check "mkdocs pipx brought in is removed, then what only it needed" "$(run_mkdocs_upgrade "${INSTALLED}" auto)" \
  "0:apt-get purge -y mkdocs;apt-get autoremove --purge -y;"
unset -f dpkg-query apt-mark apt-get run_mkdocs_upgrade

echo "remove_ktls_utils"
run_ktls_upgrade() {
  local status=0
  rm -f "${WORK}/ktls-calls"
  KTLS_STATUS="$1" remove_ktls_utils > /dev/null 2>&1 || status=$?
  echo "${status}:$(tr '\n' ';' 2> /dev/null < "${WORK}/ktls-calls")"
}
dpkg-query() { echo "${KTLS_STATUS}"; }
apt-get() { echo "apt-get $*" >> "${WORK}/ktls-calls"; }
check "without ktls-utils, nothing is removed" "$(run_ktls_upgrade "")" "0:"
check "ktls-utils is purged" "$(run_ktls_upgrade "${INSTALLED}")" "0:apt-get purge -y ktls-utils;"
unset -f dpkg-query apt-get run_ktls_upgrade

echo "remove_unused_dev_libraries"
# Prints the upgrade's exit status and the apt-mark and apt-get commands it ran. DEV_INSTALLED
# is what dpkg-query finds; apt-get -s autoremove lists DEV_BEFORE until apt-mark has run, then
# DEV_AFTER.
run_dev_upgrade() {
  local status=0
  rm -f "${WORK}/dev-calls" "${WORK}/dev-marked"
  DEV_INSTALLED="$1" DEV_BEFORE="$2" DEV_AFTER="$3" remove_unused_dev_libraries > /dev/null 2>&1 || status=$?
  echo "${status}:$(tr '\n' ';' 2> /dev/null < "${WORK}/dev-calls")"
}
dpkg-query() {
  local p
  for p in ${DEV_INSTALLED}; do echo "ii  ${p}"; done
  echo "un  libmcrypt-dev"
}
apt-mark() { echo "apt-mark $*" >> "${WORK}/dev-calls"; touch "${WORK}/dev-marked"; }
apt-get() {
  local option="$1" p list="${DEV_BEFORE}"
  if [[ "${option}" == "-s" ]]; then
    [[ -f "${WORK}/dev-marked" ]] && list="${DEV_AFTER}"
    for p in ${list}; do echo "Remv ${p} [1.0]"; done
    return 0
  fi
  echo "apt-get $*" >> "${WORK}/dev-calls"
}
check "without the libraries, nothing is changed" "$(run_dev_upgrade "" "" "")" "0:"
check "the libraries and what only they needed are purged; a needed one and packages unneeded before stay" \
  "$(run_dev_upgrade "libssl-dev libjemalloc2" "linux-image-old" "linux-image-old libssl-dev libssl-doc")" \
  "0:apt-mark auto libssl-dev libjemalloc2;apt-get purge -y libssl-dev libssl-doc;"
check "when every library is still needed, nothing is purged" \
  "$(run_dev_upgrade "libjemalloc2" "" "")" "0:apt-mark auto libjemalloc2;"
unset -f dpkg-query apt-mark apt-get run_dev_upgrade

echo "migrate_php_fpm_oom_policy"
# PHP 8.5 has EngineScript's override as earlier versions wrote it; PHP 8.4's folder holds only
# another drop-in, which is not EngineScript's to change
export ES_SYSTEMD_DIR="${WORK}/systemd"
mkdir -p "${ES_SYSTEMD_DIR}/php8.5-fpm.service.d" "${ES_SYSTEMD_DIR}/php8.4-fpm.service.d"
printf '[Service]\nMemoryHigh=1285M\nMemoryMax=1428M\n' > "${ES_SYSTEMD_DIR}/php8.5-fpm.service.d/enginescript.conf"
printf '[Service]\nNice=5\n' > "${ES_SYSTEMD_DIR}/php8.4-fpm.service.d/admin.conf"
tuning_load() { :; }
tuning_get() { case "$1" in PHP_MEMORY_HIGH_MB) echo 1285 ;; PHP_MEMORY_MAX_MB) echo 1428 ;; esac; }
RELOADS=0
systemctl() { [[ "$1" == "daemon-reload" ]] && RELOADS=$((RELOADS + 1)); return 0; }
status=0
migrate_php_fpm_oom_policy > /dev/null || status=$?
check "the override keeps the plan's ceiling and adds OOMPolicy=continue" \
  "${status}:$(tr '\n' ';' < "${ES_SYSTEMD_DIR}/php8.5-fpm.service.d/enginescript.conf")" \
  "0:[Service];MemoryHigh=1285M;MemoryMax=1428M;OOMPolicy=continue;"
check "systemd reloads its units once" "${RELOADS}" "1"
check "another version's own drop-in is left alone, and gets no override" \
  "$(cat "${ES_SYSTEMD_DIR}/php8.4-fpm.service.d/admin.conf"):$(ls "${ES_SYSTEMD_DIR}/php8.4-fpm.service.d" | tr '\n' ' ')" \
  "[Service]
Nice=5:admin.conf "
migrate_php_fpm_oom_policy > /dev/null
check "running it again changes nothing" "${RELOADS}" "1"
tuning_get() { :; }
printf '[Service]\nMemoryHigh=1285M\nMemoryMax=1428M\n' > "${ES_SYSTEMD_DIR}/php8.5-fpm.service.d/enginescript.conf"
status=0
migrate_php_fpm_oom_policy > /dev/null 2>&1 || status=$?
check "without a plan to rewrite it from, the upgrade reports failure, so the next update tries again" "${status}" "1"
rm -rf "${ES_SYSTEMD_DIR}"
migrate_php_fpm_oom_policy
check "a server without the override is fine" "$?" "0"
unset -f tuning_load tuning_get systemctl
unset ES_SYSTEMD_DIR

echo "forget_upgrade_done"
record_upgrade_done es_test_forget
record_upgrade_done es_test_forget_keep
forget_upgrade_done es_test_forget
check "the upgrade's record is removed, and only that one" "$(upgrade_is_done es_test_forget && echo kept || echo removed):$(upgrade_is_done es_test_forget_keep && echo kept || echo removed)" "removed:kept"
forget_upgrade_done es_test_forget_missing
check "forgetting an upgrade that has no record succeeds" "$?" "0"

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
