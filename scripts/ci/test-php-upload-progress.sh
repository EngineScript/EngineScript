#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: PHP Session Upload Progress Update Step
#----------------------------------------------------------------------------------
# migrate_php_upload_progress must set session.upload_progress.enabled = Off in each PHP
# version's PHP-FPM php.ini, whatever form the setting has, keep the previous file when
# php-fpm -t fails, reload only running PHP-FPM services, and change nothing on a second run.
# php.ini files live in a temporary /etc/php; php-fpmX.Y and systemctl are stand-ins that
# record their calls.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export ES_PHP_ETC="${WORK}/etc-php"
export CALLS="${WORK}/calls.log"
mkdir -p "${WORK}/bin"

# php-fpmX.Y stand-in: fails its test when FPM_TEST_FAILS names its version
for ver in 8.3 8.4 8.5; do
  cat > "${WORK}/bin/php-fpm${ver}" << EOF
#!/usr/bin/env bash
echo "php-fpm${ver} \$*" >> "\${CALLS}"
[[ "\${FPM_TEST_FAILS:-}" == "${ver}" ]] && exit 1
exit 0
EOF
  chmod +x "${WORK}/bin/php-fpm${ver}"
done
# systemctl stand-in: the services in FPM_ACTIVE are running
cat > "${WORK}/bin/systemctl" << 'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >> "${CALLS}"
if [[ "$1" == "is-active" ]]; then
  [[ " ${FPM_ACTIVE:-} " == *" ${*: -1} "* ]]
fi
EOF
chmod +x "${WORK}/bin/systemctl"
export PATH="${WORK}/bin:${PATH}"

# Read by enginescript-common.sh
# shellcheck disable=SC2034
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
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

# Usage: check "<description>" "<actual>" "<expected>"
check() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (expected '$3', got '$2')"
  fi
}

# The php.ini of earlier EngineScript versions: the template with the setting commented
OLD_INI="${WORK}/php.ini.old"
sed 's/^session\.upload_progress\.enabled = Off$/;session.upload_progress.enabled = On/' "${REPO_ROOT}/config/etc/php/php.ini" > "${OLD_INI}"

# Usage: add_version <version> [php.ini source]
add_version() {
  mkdir -p "${ES_PHP_ETC}/$1/fpm"
  cp "${2:-${OLD_INI}}" "${ES_PHP_ETC}/$1/fpm/php.ini"
}

reset() {
  rm -rf "${ES_PHP_ETC}"
  : > "${CALLS}"
}

active_lines() {
  grep -cE '^[[:space:]]*session\.upload_progress\.enabled' "${ES_PHP_ETC}/$1/fpm/php.ini" || true
}

setting() {
  grep -E '^[[:space:]]*session\.upload_progress\.enabled' "${ES_PHP_ETC}/$1/fpm/php.ini" || true
}

echo "Template"
check "the template sets it Off" "$(grep -c '^session.upload_progress.enabled = Off$' "${REPO_ROOT}/config/etc/php/php.ini")" "1"
check "the earlier-version stand-in has it commented" "$(grep -c '^;session.upload_progress.enabled = On$' "${OLD_INI}")" "1"

echo "Earlier EngineScript php.ini (commented setting), two versions, one running"
reset
add_version 8.3
add_version 8.5
FPM_ACTIVE="php8.5-fpm" migrate_php_upload_progress > /dev/null
check "8.3 set to Off" "$(setting 8.3)" "session.upload_progress.enabled = Off"
check "8.5 set to Off" "$(setting 8.5)" "session.upload_progress.enabled = Off"
check "the commented line was replaced, not duplicated" "$(grep -c 'session.upload_progress.enabled' "${ES_PHP_ETC}/8.3/fpm/php.ini")" "1"
check "the line stays in the [Session] section" "$(awk '/^\[/ {s = $0} /^session\.upload_progress\.enabled/ {print s}' "${ES_PHP_ETC}/8.3/fpm/php.ini")" "[Session]"
check "each version's configuration tested" "$(grep -c -- ' -t$' "${CALLS}")" "2"
check "only the running service reloaded" "$(grep 'reload' "${CALLS}")" "systemctl reload php8.5-fpm"
check "no backup left" "$(find "${ES_PHP_ETC}" -name '*.pre-upload-progress' | wc -l | tr -d ' ')" "0"
cp "${ES_PHP_ETC}/8.3/fpm/php.ini" "${WORK}/after-first-run.ini"
: > "${CALLS}"
out="$(FPM_ACTIVE="php8.5-fpm" migrate_php_upload_progress)"
check "a second run changes nothing" "$(cmp -s "${WORK}/after-first-run.ini" "${ES_PHP_ETC}/8.3/fpm/php.ini" && echo same) $(wc -c < "${CALLS}" | tr -d ' ') ${out:-quiet}" "same 0 quiet"
if diff <(sed 's/^session\.upload_progress\.enabled = Off$/;session.upload_progress.enabled = On/' "${ES_PHP_ETC}/8.3/fpm/php.ini") "${OLD_INI}" > /dev/null; then
  pass "nothing else in php.ini changed"
else
  fail "other lines of php.ini changed"
fi

echo "Active setting On (an administrator's edit)"
reset
add_version 8.4
sed -i 's/^;session\.upload_progress\.enabled = On$/  session.upload_progress.enabled = "1"/' "${ES_PHP_ETC}/8.4/fpm/php.ini"
migrate_php_upload_progress > /dev/null
check "replaced with Off" "$(setting 8.4)" "session.upload_progress.enabled = Off"
check "one setting line" "$(active_lines 8.4)" "1"

echo "Already off in another spelling"
for value in off 0 '"Off"' false; do
  reset
  add_version 8.4
  sed -i "s/^;session\.upload_progress\.enabled = On$/session.upload_progress.enabled = ${value}/" "${ES_PHP_ETC}/8.4/fpm/php.ini"
  migrate_php_upload_progress > /dev/null
  check "'${value}' left as is, no test or reload" "$(setting 8.4) $(wc -c < "${CALLS}" | tr -d ' ')" "session.upload_progress.enabled = ${value} 0"
done

echo "No setting at all"
reset
add_version 8.4
sed -i '/session\.upload_progress\.enabled/d' "${ES_PHP_ETC}/8.4/fpm/php.ini"
migrate_php_upload_progress > /dev/null
check "added right after [Session]" "$(grep -A1 '^\[Session\]' "${ES_PHP_ETC}/8.4/fpm/php.ini" | tail -1)" "session.upload_progress.enabled = Off"
reset
add_version 8.4
printf 'memory_limit = 256M\n' > "${ES_PHP_ETC}/8.4/fpm/php.ini"
migrate_php_upload_progress > /dev/null
check "no [Session] section: appended" "$(tail -1 "${ES_PHP_ETC}/8.4/fpm/php.ini")" "session.upload_progress.enabled = Off"

echo "php-fpm -t fails"
reset
add_version 8.3
add_version 8.4
FPM_TEST_FAILS=8.3 FPM_ACTIVE="php8.3-fpm php8.4-fpm" migrate_php_upload_progress > /dev/null 2> "${WORK}/err.log"
if cmp -s "${OLD_INI}" "${ES_PHP_ETC}/8.3/fpm/php.ini"; then
  pass "8.3: previous php.ini kept"
else
  fail "8.3: php.ini changed although the test failed"
fi
check "8.3: error reported" "$(grep -c 'php-fpm8.3 -t failed' "${WORK}/err.log")" "1"
check "8.3: not reloaded; 8.4 changed and reloaded" "$(grep 'reload' "${CALLS}") | $(setting 8.4)" "systemctl reload php8.4-fpm | session.upload_progress.enabled = Off"
check "no backup left" "$(find "${ES_PHP_ETC}" -name '*.pre-upload-progress' | wc -l | tr -d ' ')" "0"

echo "No PHP installed"
reset
if migrate_php_upload_progress > /dev/null; then
  pass "nothing to do"
else
  fail "failed without PHP"
fi

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
