#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Automatic Software Updates
#----------------------------------------------------------------------------------
# The decisions of enginescript-auto-update.sh: a missing AUTO_UPDATE_* option is on, the
# maintainer's pause skips a part, a new release waits AUTO_UPDATE_DELAY_DAYS days, a release
# whose update failed is not tried again, and the Nginx build fingerprint tells whether the
# server is behind (recorded without a rebuild on a server that is already current).

# The settings and versions set here are read by the functions under test
# shellcheck disable=SC2034

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export ES_AUTO_UPDATE_DIR="${WORK}/auto-update"

# Read by enginescript-common.sh
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"
# shellcheck source=scripts/functions/shared/enginescript-auto-update.sh
source "${REPO_ROOT}/scripts/functions/shared/enginescript-auto-update.sh"

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

# Prints "due", or "wait" with a reason on stderr left out
due() {
  if ES_AUTO_UPDATE_TODAY="$1" auto_update_due "$2" "$3" > /dev/null; then
    echo "due"
  else
    echo "wait"
  fi
}

echo "Settings"
unset AUTO_UPDATE_NGINX AUTO_UPDATE_PHP AUTO_UPDATE_MARIADB AUTO_UPDATE_DELAY_DAYS
resolve_auto_update_settings
check "missing options are on, and the wait is one day" "${AUTO_UPDATE_NGINX}${AUTO_UPDATE_PHP}${AUTO_UPDATE_MARIADB}/${AUTO_UPDATE_DELAY_DAYS}" "111/1"
AUTO_UPDATE_NGINX=0 AUTO_UPDATE_PHP="yes" AUTO_UPDATE_MARIADB="" AUTO_UPDATE_DELAY_DAYS="soon"
resolve_auto_update_settings
check "only 0 switches a part off, and an invalid wait is one day" "${AUTO_UPDATE_NGINX}${AUTO_UPDATE_PHP}${AUTO_UPDATE_MARIADB}/${AUTO_UPDATE_DELAY_DAYS}" "011/1"
check "auto_update_enabled follows the option" "$(auto_update_enabled nginx && echo on || echo off)/$(auto_update_enabled php && echo on || echo off)" "off/on"
AUTO_UPDATE_DELAY_DAYS=3
resolve_auto_update_settings
check "a wait in days is kept" "${AUTO_UPDATE_DELAY_DAYS}" "3"

echo "Pause"
AUTO_UPDATE_PAUSED=""
check "nothing is paused by default" "$(auto_update_paused nginx && echo paused || echo running)" "running"
AUTO_UPDATE_PAUSED="nginx mariadb"
check "a named part is paused" "$(auto_update_paused nginx && echo paused || echo running)/$(auto_update_paused mariadb && echo paused || echo running)" "paused/paused"
check "the other parts are not" "$(auto_update_paused php && echo paused || echo running)" "running"
AUTO_UPDATE_PAUSED="php,nginx"
check "commas separate parts too" "$(auto_update_paused nginx && echo paused || echo running)" "paused"
AUTO_UPDATE_PAUSED="all"
check "all pauses every part" "$(auto_update_paused php && echo paused || echo running)" "paused"
AUTO_UPDATE_PAUSED=""

echo "Waiting period"
AUTO_UPDATE_DELAY_DAYS=1
check "a release seen for the first time waits" "$(due 2026-11-10 nginx "release-1")" "wait"
check "it is recorded with the day" "$(tr '\n' ' ' < "${ES_AUTO_UPDATE_DIR}/nginx.pending")" "release-1 2026-11-10 "
check "it still waits later the same day" "$(due 2026-11-10 nginx "release-1")" "wait"
check "the reason names the day" "$(ES_AUTO_UPDATE_TODAY=2026-11-10 auto_update_due nginx "release-1" | grep -c 'first seen on 2026-11-10')" "1"
check "it is due the next day" "$(due 2026-11-11 nginx "release-1")" "due"
check "and stays due after that" "$(due 2026-11-15 nginx "release-1")" "due"
check "a newer release starts its own wait" "$(due 2026-11-15 nginx "release-2")" "wait"
check "the newer release is due a day later" "$(due 2026-11-16 nginx "release-2")" "due"
check "each part waits on its own" "$(due 2026-11-16 mariadb "11.8.9")" "wait"
check "a wait across a month end counts days" "$(due 2026-11-30 php "8.5.2")/$(due 2026-12-01 php "8.5.2")" "wait/due"
AUTO_UPDATE_DELAY_DAYS=3
check "a three-day wait is not over after two days" "$(due 2026-11-17 nginx "release-2")" "wait"
check "a three-day wait is over after three days" "$(due 2026-11-18 nginx "release-2")" "due"
AUTO_UPDATE_DELAY_DAYS=0
check "no wait installs a new release at once" "$(due 2026-11-20 nginx "release-3")" "due"
AUTO_UPDATE_DELAY_DAYS=1
printf 'release-4\nnot a day\n' > "${ES_AUTO_UPDATE_DIR}/nginx.pending"
check "a damaged record starts the wait again" "$(due 2026-11-21 nginx "release-4")/$(sed -n 2p "${ES_AUTO_UPDATE_DIR}/nginx.pending")" "wait/2026-11-21"

echo "Failed releases"
auto_update_record_failed nginx "release-4"
check "a release whose update failed is not tried again" "$(due 2026-11-30 nginx "release-4")" "wait"
check "the reason says so" "$(ES_AUTO_UPDATE_TODAY=2026-11-30 auto_update_due nginx "release-4" | grep -c 'failed before')" "1"
check "the next release is tried (after its wait)" "$(due 2026-11-30 nginx "release-5")/$(due 2026-12-01 nginx "release-5")" "wait/due"
auto_update_record_failed nginx "release-5"
auto_update_clear nginx
check "a successful update forgets the failed and waiting releases" "$(find "${ES_AUTO_UPDATE_DIR}" -name 'nginx.*' | wc -l | tr -d ' ')" "0"
check "the release it failed on can then be tried again" "$(due 2026-12-02 nginx "release-5")/$(due 2026-12-03 nginx "release-5")" "wait/due"
auto_update_clear nginx

echo "Last result"
auto_update_record_last nginx updated "Nginx 1.2.3"
check "the last automatic update is recorded" "$(cut -d' ' -f2- "${ES_AUTO_UPDATE_DIR}/nginx.last")" "updated: Nginx 1.2.3"

echo "Nginx build fingerprint"
NGINX_VER="1.31.8" OPENSSL_VER="4.1.0" PCRE2_VER="10.49" ZLIB_VER="1.3.2" ZLIB_NG_VER="2.3.3" ZLIB_RS_VER="v0.6.8"
NGINX_HEADER_VER="0.41" NGINX_PURGE_VER="3.0.4" INSTALL_HTTP3=0 ZLIB_IMPLEMENTATION="" NGINX_BUILD_REV="1"
BASE="$(nginx_build_fingerprint)"
check "it names what is compiled in" "${BASE}" "nginx=1.31.8 openssl=4.1.0 pcre2=10.49 zlib=zlib-1.3.2 headers-more=0.41 cache-purge=3.0.4 http3=0 rev=1"
# Usage: changes "<assignment>": prints "changed" when the assignment gives another fingerprint
changes() {
  (
    eval "$1"
    [[ "$(nginx_build_fingerprint)" != "${BASE}" ]] && echo "changed" || echo "same"
  )
}
for assignment in 'NGINX_VER=1.31.9' 'OPENSSL_VER=4.1.1' 'PCRE2_VER=10.50' 'ZLIB_VER=1.3.3' 'NGINX_HEADER_VER=0.42' \
  'NGINX_PURGE_VER=3.0.5' 'INSTALL_HTTP3=1' 'ZLIB_IMPLEMENTATION=zlib-ng' 'ZLIB_IMPLEMENTATION=zlib-rs' 'NGINX_BUILD_REV=2'; do
  check "${assignment} changes it" "$(changes "${assignment}")" "changed"
done
check "a zlib that is not compiled in does not change it" "$(changes 'ZLIB_NG_VER=2.4.0')/$(changes 'ZLIB_RS_VER=v0.7.0')" "same/same"
check "the zlib-ng version counts when zlib-ng is selected" "$(ZLIB_IMPLEMENTATION="zlib-ng"; a="$(nginx_build_fingerprint)"; ZLIB_NG_VER=2.4.0; [[ "$(nginx_build_fingerprint)" != "${a}" ]] && echo changed || echo same)" "changed"

echo "Nginx: is the server behind"
# nginx stand-in: prints the build information of the version in FAKE_NGINX_VER / FAKE_OPENSSL_VER
cat > "${WORK}/nginx" << 'EOF'
#!/usr/bin/env bash
{
  echo "nginx version: nginx/${FAKE_NGINX_VER} (nginx-${FAKE_NGINX_VER}-11-09-26-enginescript)"
  echo "built by gcc 15.2.0 (Ubuntu 15.2.0-4ubuntu4)"
  echo "built with OpenSSL ${FAKE_OPENSSL_VER} 1 Oct 2026"
  echo "TLS SNI support enabled"
} >&2
EOF
chmod +x "${WORK}/nginx"
export ES_NGINX_BIN="${WORK}/nginx"
export FAKE_NGINX_VER="1.31.8" FAKE_OPENSSL_VER="4.1.0"

check "a current server without a record is up to date" "$(nginx_auto_update_target)" ""
nginx_auto_update_target > /dev/null
check "its fingerprint is recorded without a rebuild" "$(cat "${ES_AUTO_UPDATE_DIR}/nginx.installed")" "${BASE}"
rm -f "${ES_AUTO_UPDATE_DIR}/nginx.installed"
check "an older Nginx without a record is behind" "$(FAKE_NGINX_VER=1.31.7 nginx_auto_update_target)" "${BASE}"
check "nothing is recorded for it" "$([[ -e "${ES_AUTO_UPDATE_DIR}/nginx.installed" ]] && echo recorded || echo none)" "none"
check "a version that only starts the same is behind" "$(FAKE_NGINX_VER=1.31.80 nginx_auto_update_target)" "${BASE}"
check "an older OpenSSL without a record is behind" "$(FAKE_OPENSSL_VER=4.0.2 nginx_auto_update_target)" "${BASE}"
check "a server without Nginx's build information is behind" "$(ES_NGINX_BIN="${WORK}/missing" nginx_auto_update_target 2> /dev/null)" "${BASE}"

record_nginx_build_fingerprint
check "after a build the server is up to date" "$(nginx_auto_update_target)" ""
check "a new PCRE2 release puts it behind" "$(PCRE2_VER=10.50; nginx_auto_update_target)" "nginx=1.31.8 openssl=4.1.0 pcre2=10.50 zlib=zlib-1.3.2 headers-more=0.41 cache-purge=3.0.4 http3=0 rev=1"
check "the record wins over the binary's versions" "$(FAKE_NGINX_VER=1.0.0 nginx_auto_update_target)" ""

echo "The scripts that keep the fingerprint"
check "nginx-update.sh records it after its checks pass" "$(sed -n '/^echo "PASSED: Nginx is running."/,$p' "${REPO_ROOT}/scripts/update/nginx-update.sh" | grep -c '^record_nginx_build_fingerprint$')" "1"
check "nginx-install.sh records it" "$(grep -c '^record_nginx_build_fingerprint$' "${REPO_ROOT}/scripts/install/nginx/nginx-install.sh")" "1"
# shellcheck disable=SC2016  # ${SCHEDULED} is text to find in the script, not a variable here
check "only the scheduled EngineScript update starts the automatic updates" \
  "$(grep -B12 'software-auto-update.sh >>' "${REPO_ROOT}/scripts/update/enginescript-update.sh" | grep -c '^if \[\[ "${SCHEDULED}" == "1" \]\]; then$')" "1"
for script in mariadb-update.sh php-patch-update.sh; do
  check "${script} forgets the waiting and failed releases after a successful update" \
    "$(grep -c "auto_update_clear \"$( [[ "${script}" == mariadb* ]] && echo mariadb || echo php)\"" "${REPO_ROOT}/scripts/update/${script}")" \
    "$( [[ "${script}" == mariadb* ]] && echo 1 || echo 2)"
done

# dpkg-query and apt-cache stand-ins: the installed and offered versions in FAKE_INSTALLED and
# FAKE_CANDIDATE (empty: not installed / not offered)
dpkg-query() { [[ -n "${FAKE_INSTALLED}" ]] && printf '%s' "${FAKE_INSTALLED}"; }
apt-cache() { [[ -n "${FAKE_CANDIDATE}" ]] && printf 'php8.5-fpm:\n  Installed: %s\n  Candidate: %s\n' "${FAKE_INSTALLED}" "${FAKE_CANDIDATE}"; }

echo "MariaDB"
MARIADB_VER="11.8.9"
# Usage: mariadb_case <installed package version>: prints "<target>|<newer series>"
mariadb_case() { FAKE_INSTALLED="$1"; echo "$(mariadb_auto_update_target)|$(mariadb_newer_series)"; }
check "the installed version is read from the package version" "$(FAKE_INSTALLED="1:11.8.7+maria~ubu2604"; mariadb_installed_version)" "11.8.7"
check "an older patch release of the series is updated" "$(mariadb_case "1:11.8.7+maria~ubu2604")" "11.8.9|"
check "the current release is up to date" "$(mariadb_case "1:11.8.9+maria~ubu2404")" "|"
check "a patch release newer than MARIADB_VER is never downgraded" "$(mariadb_case "1:11.8.10+maria~ubu2604")" "|"
check "an older series is not updated, and gets a note" "$(mariadb_case "1:11.4.8+maria~ubu2404")" "|11.8.9"
check "a newer series is not updated, and gets no note" "$(mariadb_case "1:12.2.1+maria~ubu2604")" "|"
check "without MariaDB nothing happens" "$(mariadb_case "")" "|"

echo "PHP"
PHP_TESTED_BUILDS=("8.4=8.4.27-1+0~20261021.57" "8.5=8.5.12-1+0~20261021.27")
check "the tested build of a version" "$(php_tested_build 8.5)" "8.5.12-1+0~20261021.27"
check "a version without a tested build" "$(php_tested_build 8.3)" ""
check "the Ubuntu part is left out of a build" "$(php_build_of "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a")" "8.5.12-1+0~20261021.27"
# Usage: php_case <installed> <candidate>: the target, then whether a wait was reported
php_case() {
  local reason
  FAKE_INSTALLED="$1" FAKE_CANDIDATE="$2"
  reason="$(php_auto_update_target 8.5 2>&1 > /dev/null)"
  echo "$(php_auto_update_target 8.5 2> /dev/null)|$([[ -n "${reason}" ]] && echo waits || echo quiet)"
}
check "the tested build is installed" "$(php_case "8.5.11-1+0~20260920.12+ubuntu26.04~1.gbp0a1b2c" "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a")" "8.5.12-1+0~20261021.27|quiet"
check "the same tested build on Ubuntu 24.04" "$(php_case "8.5.11-1+0~20260920.12+ubuntu24.04~1.gbp0a1b2c" "8.5.12-1+0~20261021.27+ubuntu24.04~1.gbp1a3e8a")" "8.5.12-1+0~20261021.27|quiet"
check "a build Sury published after the tested one waits" "$(php_case "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a" "8.5.13-1+0~20261118.30+ubuntu26.04~1.gbp9f8e7d")" "|waits"
check "a rebuild of the same release that was not tested waits" "$(php_case "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a" "8.5.12-2+0~20261101.28+ubuntu26.04~1.gbp1111aa")" "|waits"
check "the installed build is up to date" "$(php_case "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a" "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a")" "|quiet"
check "without a candidate nothing happens" "$(php_case "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a" "")" "|quiet"
check "a candidate of (none) is nothing to do" "$(php_case "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a" "(none)")" "|quiet"
PHP_TESTED_BUILDS=()
check "no tested build: the server waits" "$(php_case "8.5.11-1+0~20260920.12+ubuntu26.04~1.gbp0a1b2c" "8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a")" "|waits"
unset -f dpkg-query apt-cache
SUPPORTED_PHP_VERSIONS=("8.3" "8.4" "8.5")
check "a newer supported version is reported" "$(php_newer_version 8.4)" "8.5"
check "the newest version reports nothing" "$(php_newer_version 8.5)" ""
check "an unsupported newer version reports nothing" "$(php_newer_version 8.6)" ""
SUPPORTED_PHP_VERSIONS=("8.4" "8.5" "8.10")
check "versions compare as numbers (8.10 after 8.5)" "$(php_newer_version 8.5)" "8.10"

echo "One-time notes"
NOTES=0
notify_admin() { NOTES=$((NOTES + 1)); }
auto_update_notice_once "php-version" "8.6" "PHP 8.6 is supported." > /dev/null
auto_update_notice_once "php-version" "8.6" "PHP 8.6 is supported." > /dev/null
check "a note is sent once" "${NOTES}" "1"
auto_update_notice_once "php-version" "8.7" "PHP 8.7 is supported." > /dev/null
check "a new value sends a new note" "${NOTES}" "2"
auto_update_notice_once "mariadb-series" "12.2" "MariaDB 12.2." > /dev/null
check "each note has its own record" "${NOTES}" "3"
notify_admin() { return 1; }
auto_update_notice_once "mariadb-series" "12.3" "MariaDB 12.3." > /dev/null || true
check "a note that could not be sent is sent again next time" "$(cat "${ES_AUTO_UPDATE_DIR}/mariadb-series.notified")" "12.2"
unset -f notify_admin

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
