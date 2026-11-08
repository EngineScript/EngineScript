#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: PHP Version Detection
#----------------------------------------------------------------------------------
# resolve_php_version must use the PHP-FPM version installed on the server, so scripts such
# as the Nginx update never point at a PHP-FPM socket that does not exist. dpkg-query and
# systemctl are replaced with stand-ins that report the packages and services each case sets.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "${FAKE_BIN}"' EXIT

# dpkg-query stand-in: prints FAKE_DPKG_LINES ("<package> <status>" lines)
cat > "${FAKE_BIN}/dpkg-query" << 'EOF'
#!/usr/bin/env bash
if [[ -n "${FAKE_DPKG_LINES:-}" ]]; then
  printf '%s\n' "${FAKE_DPKG_LINES}"
  exit 0
fi
exit 1
EOF
# systemctl stand-in: "is-active --quiet phpX.Y-fpm" succeeds for versions in FAKE_ACTIVE
cat > "${FAKE_BIN}/systemctl" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "is-active" ]]; then
  service="${!#}"
  for ver in ${FAKE_ACTIVE:-}; do
    [[ "${service}" == "php${ver}-fpm" ]] && exit 0
  done
  exit 3
fi
exit 0
EOF
# curl stand-in for get_sites_without_php: prints the status FAKE_HTTP_CODES gives the site
# ("<site>=<code> ..."; 000 when a site is not listed)
cat > "${FAKE_BIN}/curl" << 'EOF'
#!/usr/bin/env bash
url="${!#}"
site="${url#https://}"
site="${site%%/*}"
code="000"
for pair in ${FAKE_HTTP_CODES:-}; do
  [[ "${pair%%=*}" == "${site}" ]] && code="${pair#*=}"
done
printf '%s' "${code}"
EOF
chmod +x "${FAKE_BIN}/dpkg-query" "${FAKE_BIN}/systemctl" "${FAKE_BIN}/curl"
export PATH="${FAKE_BIN}:${PATH}"

# Read by enginescript-common.sh
# shellcheck disable=SC2034
PHP_VER="8.5"
# shellcheck disable=SC2034
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
PHP_VERSION_OVERRIDE=""
export FAKE_DPKG_LINES=""
export FAKE_ACTIVE=""

source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"

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

# Usage: check_case "<description>" "<dpkg lines>" "<active versions>" "<override>" "<expected PHP_VER>" "<expected PHP_CONFIGURED_VER>"
check_case() {
  local description="$1"
  FAKE_DPKG_LINES="$2"
  FAKE_ACTIVE="$3"
  # shellcheck disable=SC2034
  PHP_VERSION_OVERRIDE="$4"
  PHP_VER="8.5"
  resolve_php_version
  if [[ "${PHP_VER}" == "$5" && "${PHP_CONFIGURED_VER}" == "$6" ]]; then
    pass "${description}"
  else
    fail "${description}: PHP_VER=${PHP_VER} (expected $5), PHP_CONFIGURED_VER=${PHP_CONFIGURED_VER} (expected $6)"
  fi
}

echo "======================================================="
echo "PHP Version Detection Tests"
echo "======================================================="

check_case "New server uses the default version" \
  "" "" "" "8.5" "8.5"
check_case "New server uses a supported override" \
  "" "" "8.4" "8.4" "8.4"
check_case "Unsupported override is ignored" \
  "" "" "8.2" "8.5" "8.5"
check_case "Installed older version wins over the newer default" \
  "php8.4-fpm install ok installed" "8.4" "" "8.4" "8.5"
check_case "Installed version is used even when it is no longer supported" \
  "php8.2-fpm install ok installed" "8.2" "" "8.2" "8.5"
check_case "Installed version is used when its service is stopped" \
  "php8.4-fpm install ok installed" "" "" "8.4" "8.5"
check_case "Two installed: the running version is used" \
  $'php8.4-fpm install ok installed\nphp8.5-fpm install ok installed' "8.4" "" "8.4" "8.5"
check_case "Two installed, neither running: the newest is used" \
  $'php8.4-fpm install ok installed\nphp8.5-fpm install ok installed' "" "" "8.5" "8.5"
check_case "Removed package with leftover config files is not counted" \
  $'php8.3-fpm deinstall ok config-files\nphp8.4-fpm install ok installed' "" "" "8.4" "8.5"
check_case "The php-fpm meta package is not counted" \
  $'php-fpm install ok installed\nphp8.5-fpm install ok installed' "8.5" "" "8.5" "8.5"

FAKE_DPKG_LINES=$'php8.3-fpm install ok installed\nphp8.10-fpm install ok installed\nphp8.4-fpm install ok installed'
FAKE_ACTIVE=""
listed="$(get_installed_php_versions | paste -sd' ' -)"
if [[ "${listed}" == "8.10 8.4 8.3" ]]; then
  pass "Installed versions are listed newest first (version order, not text order)"
else
  fail "Installed versions listed as '${listed}', expected '8.10 8.4 8.3'"
fi

new_failures="$(newly_failing_sites $'a.com\nb.com' $'b.com\nc.com')"
if [[ "${new_failures}" == "c.com" ]]; then
  pass "Only sites that fail after a change, and not before it, are reported"
else
  fail "newly_failing_sites reported '${new_failures}', expected 'c.com'"
fi
if [[ -z "$(newly_failing_sites "" "")" ]]; then
  pass "No sites, no failures"
else
  fail "newly_failing_sites reported failures for empty lists"
fi

# The site check after a PHP switch or an Nginx update: which answers count as a failing site
export ES_SITES_LIST="${FAKE_BIN}/sites.sh"
cat > "${ES_SITES_LIST}" << 'EOF'
SITES=(
"ok.test"
"fatal.test"
"gateway.test"
"timeout.test"
"maintenance.test"
"missing.test"
)
EOF
export FAKE_HTTP_CODES="ok.test=200 fatal.test=500 gateway.test=502 timeout.test=504 maintenance.test=503 missing.test=404"
failing="$(get_sites_without_php | paste -sd' ' -)"
if [[ "${failing}" == "fatal.test gateway.test timeout.test" ]]; then
  pass "Sites answering 500, 502, or 504 fail the site check; 200, 503, and 404 do not"
else
  fail "get_sites_without_php reported '${failing}', expected 'fatal.test gateway.test timeout.test'"
fi
FAKE_HTTP_CODES="ok.test=200"
failing="$(get_sites_without_php | paste -sd' ' -)"
if [[ "${failing}" == "fatal.test gateway.test timeout.test maintenance.test missing.test" ]]; then
  pass "Sites that do not answer at all fail the site check"
else
  fail "get_sites_without_php reported '${failing}' for sites that do not answer"
fi
# A site that already failed before the switch does not block it
new_failures="$(newly_failing_sites "fatal.test" "$(FAKE_HTTP_CODES="ok.test=200 fatal.test=500 gateway.test=200 timeout.test=200 maintenance.test=200 missing.test=200" get_sites_without_php)")"
if [[ -z "${new_failures}" ]]; then
  pass "A site that returned 500 before the change is not held against it"
else
  fail "newly_failing_sites reported '${new_failures}' for a site that already failed"
fi
ES_SITES_LIST="${FAKE_BIN}/no-such-sites.sh"
if [[ -z "$(get_sites_without_php)" ]]; then
  pass "No sites list, no failing sites"
else
  fail "get_sites_without_php reported sites without a sites list"
fi

echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
