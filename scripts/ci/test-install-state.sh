#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Install State Helpers
#----------------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# shellcheck disable=SC2034  # read by the EngineScript functions under test
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
# shellcheck disable=SC2034  # read by the EngineScript functions under test
PHP_VERSION_OVERRIDE=""

source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"

TESTS_PASSED=0
TESTS_FAILED=0
INSTALL_STATE_FILE="$(mktemp)"
INSTALL_OPTIONS_FILE="$(mktemp)"
TEST_ASSET_DIR="$(mktemp -d)"
export ENGINESCRIPT_WP_CLI_BIN="${INSTALL_STATE_FILE}.wp"
export ENGINESCRIPT_INSTALL_STATE_FILE="${INSTALL_STATE_FILE}"
export ENGINESCRIPT_INSTALL_OPTIONS_FILE="${INSTALL_OPTIONS_FILE}"
export ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH="${TEST_ASSET_DIR}/control-panel/index.html"
export ENGINESCRIPT_PHPMYADMIN_PATH="${TEST_ASSET_DIR}/phpmyadmin/config.inc.php"

cleanup() {
  rm -f "${INSTALL_STATE_FILE}"
  rm -f "${INSTALL_OPTIONS_FILE}"
  rm -rf "${TEST_ASSET_DIR}"
}
trap cleanup EXIT

pass() {
  echo "  PASSED: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo "  FAILED: $1" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_state_value() {
  local flag_name="$1"
  local expected_value="$2"
  local actual_value

  actual_value="$(awk -F= -v key="${flag_name}" '$1 == key { value = $2 } END { print value }' "${INSTALL_STATE_FILE}")"

  if [[ "${actual_value}" == "${expected_value}" ]]; then
    pass "${flag_name}=${expected_value}"
  else
    fail "${flag_name} expected ${expected_value}, got ${actual_value:-missing}"
  fi
}

assert_single_state_line() {
  local flag_name="$1"
  local expected_count="1"
  local actual_count

  actual_count="$(grep -c "^${flag_name}=" "${INSTALL_STATE_FILE}" || true)"

  if [[ "${actual_count}" == "${expected_count}" ]]; then
    pass "${flag_name} appears once"
  else
    fail "${flag_name} expected ${expected_count} line, got ${actual_count}"
  fi
}

complete_install_state() {
  local flag_name

  : > "${INSTALL_STATE_FILE}"
  initialize_install_state_file

  for flag_name in "${expected_flags[@]}"; do
    if [[ "${flag_name}" == "DO_CONSOLE" ]]; then
      set_install_state "${flag_name}" "0"
    else
      set_install_state "${flag_name}" "1"
    fi
  done
}

assert_installation_completion_passes() {
  local description="$1"

  if check_installation_completion "true" >/dev/null 2>&1; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

assert_installation_completion_fails() {
  local description="$1"

  if check_installation_completion "true" >/dev/null 2>&1; then
    fail "${description}"
  else
    pass "${description}"
  fi
}

expected_flags=(
  "ALIAS"
  "REPOS"
  "REMOVES"
  "BLOCK"
  "UBUNTU_PRO"
  "DEPENDS"
  "CRON"
  "ACME"
  "GCC"
  "SWAP"
  "KERNEL_TWEAKS"
  "THP"
  "SFL"
  "NTP"
  "DO_CONSOLE"
  "LIBURING"
  "UFW"
  "MARIADB"
  "PHP"
  "REDIS"
  "NGINX"
  "PHPMYADMIN"
  "ADMIN_CONTROL_PANEL"
  "WP_CLI"
  "TOOLS"
)

echo ""
echo "======================================================="
echo "  Test: Install state defaults and updates"
echo "======================================================="
echo ""

initialize_install_state_file

line_count="$(wc -l < "${INSTALL_STATE_FILE}")"
if [[ "${line_count}" -eq "${#expected_flags[@]}" ]]; then
  pass "install-state contains every expected flag"
else
  fail "install-state expected ${#expected_flags[@]} lines, got ${line_count}"
fi

for flag_name in "${expected_flags[@]}"; do
  assert_state_value "${flag_name}" "0"
done

set_install_state "WP_CLI" "1"
assert_state_value "WP_CLI" "1"
assert_single_state_line "WP_CLI"

{
  echo "WP_CLI=0"
  echo "TOOLS=1"
  echo "WP_CLI=1"
} > "${INSTALL_STATE_FILE}"

initialize_install_state_file
assert_state_value "WP_CLI" "1"
assert_state_value "TOOLS" "1"
assert_single_state_line "WP_CLI"

complete_install_state
# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_PHPMYADMIN=1
# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0
assert_installation_completion_passes "check_installation_completion passes with all required flags complete"

set_install_state "ADMIN_CONTROL_PANEL" "0"
assert_installation_completion_fails "check_installation_completion fails when ADMIN_CONTROL_PANEL is incomplete"

set_install_state "ADMIN_CONTROL_PANEL" "1"
set_install_state "PHPMYADMIN" "0"
assert_installation_completion_fails "check_installation_completion fails when enabled PHPMYADMIN is incomplete"

# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_PHPMYADMIN=0
assert_installation_completion_passes "check_installation_completion ignores PHPMYADMIN when disabled"

# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_PHPMYADMIN=1
set_install_state "PHPMYADMIN" "1"
set_install_state "WP_CLI" "0"
assert_installation_completion_fails "check_installation_completion fails when WP_CLI is incomplete"

set_install_state "WP_CLI" "1"
# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=1
assert_installation_completion_fails "check_installation_completion requires DO_CONSOLE when enabled"

set_install_state "DO_CONSOLE" "1"
assert_installation_completion_passes "check_installation_completion passes when optional DO_CONSOLE is complete"

complete_install_state
# shellcheck disable=SC2034  # read by the EngineScript functions under test
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0
set_install_state "ADMIN_CONTROL_PANEL" "0"
set_install_state "PHPMYADMIN" "0"
mkdir -p "$(dirname "${ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH}")" "$(dirname "${ENGINESCRIPT_PHPMYADMIN_PATH}")"
touch "${ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH}" "${ENGINESCRIPT_PHPMYADMIN_PATH}"
assert_installation_completion_passes "check_installation_completion backfills admin frontend flags from older TOOLS installs"
assert_state_value "ADMIN_CONTROL_PANEL" "1"
assert_state_value "PHPMYADMIN" "1"

# The install state is data: nothing in the file runs, and only the install flags are loaded.
# Before November 2026 www-data owned the file's folder, so a hacked site could write to it.
complete_install_state
PROOF_FILE="${TEST_ASSET_DIR}/ran-as-root"
# shellcheck disable=SC2034  # must keep its value: the file below tries to set it
TEST_MODE=0
{
  echo "touch '${PROOF_FILE}'"
  echo "NGINX=0; touch '${PROOF_FILE}'"
  echo "REDIS=\$(touch '${PROOF_FILE}')"
  echo "TEST_MODE=1"
  echo "PHP=2"
  echo " MARIADB=0"
  echo "OPENSSL=1"
} >> "${INSTALL_STATE_FILE}"
assert_installation_completion_passes "check_installation_completion ignores lines that are not FLAG=0 or FLAG=1"
if [[ ! -e "${PROOF_FILE}" ]]; then
  pass "a command in install-state.conf does not run"
else
  fail "a command in install-state.conf ran"
fi
if [[ "${TEST_MODE}" == "0" ]]; then
  pass "a variable that is not an install flag is not loaded"
else
  fail "install-state.conf set TEST_MODE"
fi
if [[ "$(grep -vcE '^[A-Z0-9_]+=[01]$' "${INSTALL_STATE_FILE}" || true)" == "0" ]]; then
  pass "the lines that are not flags are removed from the file"
else
  fail "install-state.conf still has lines that are not flags"
fi
assert_state_value "OPENSSL" "1"
assert_state_value "TEST_MODE" "1"
load_install_state
if [[ "${NGINX}${REDIS}${PHP}${MARIADB}" == "1111" ]]; then
  pass "load_install_state keeps the flags' real values"
else
  fail "load_install_state read NGINX REDIS PHP MARIADB as '${NGINX}${REDIS}${PHP}${MARIADB}'"
fi

# A flag missing from the file is 0, whatever the variable held before
sed -i '/^NGINX=/d' "${INSTALL_STATE_FILE}"
# shellcheck disable=SC2034  # reset by load_install_state
NGINX=1
load_install_state
if [[ "${NGINX}" == "0" ]]; then
  pass "a flag the file does not have is 0"
else
  fail "a flag the file does not have kept the value ${NGINX}"
fi
if (ENGINESCRIPT_INSTALL_STATE_FILE="${TEST_ASSET_DIR}/missing.conf"; ! load_install_state && [[ "${REPOS}${TOOLS}" == "00" ]]); then
  pass "without a file, load_install_state fails and every flag is 0"
else
  fail "load_install_state without a file"
fi

# install_has_started: only setup.sh's own flag set is still a new install
: > "${INSTALL_STATE_FILE}"
initialize_install_state_file
set_install_state "ALIAS" "1"
load_install_state
if ! install_has_started; then
  pass "install_has_started: a server with only ALIAS set is a new install"
else
  fail "install_has_started counted ALIAS as an install step"
fi
set_install_state "REPOS" "1"
load_install_state
if install_has_started; then
  pass "install_has_started: one finished step means the install has started"
else
  fail "install_has_started missed a finished step"
fi

# A link at the state file's path is replaced, never written through
LINK_DIR="${TEST_ASSET_DIR}/linked"
mkdir -p "${LINK_DIR}"
echo "REPOS=1" > "${LINK_DIR}/victim"
ln -s "${LINK_DIR}/victim" "${LINK_DIR}/install-state.conf"
(
  ENGINESCRIPT_INSTALL_STATE_FILE="${LINK_DIR}/install-state.conf"
  set_install_state "NGINX" "1" && initialize_install_state_file
)
if [[ ! -L "${LINK_DIR}/install-state.conf" && "$(cat "${LINK_DIR}/victim")" == "REPOS=1" ]] \
    && grep -qx "NGINX=1" "${LINK_DIR}/install-state.conf" && grep -qx "REPOS=0" "${LINK_DIR}/install-state.conf"; then
  pass "a link in place of install-state.conf is replaced, and the file it pointed to is neither read nor changed"
else
  fail "install-state.conf written or read through a link"
fi
if [[ -z "$(find "${LINK_DIR}" -name '.install-state.*')" ]]; then
  pass "no temporary state file is left behind"
else
  fail "a temporary state file was left behind"
fi

# set_enginescript_etc_permissions: root takes the folder over. chown is a stand-in that records
# its calls, so the test also runs without root.
ETC_DIR="${TEST_ASSET_DIR}/etc-enginescript"
mkdir -p "${ETC_DIR}"
echo "REPOS=1" > "${ETC_DIR}/install-state.conf"
echo "api_key=" > "${ETC_DIR}/uptimerobot.conf"
echo "secret" > "${TEST_ASSET_DIR}/outside-file"
chmod 600 "${TEST_ASSET_DIR}/outside-file"
chmod 666 "${ETC_DIR}/install-state.conf"
ln -s "${TEST_ASSET_DIR}/outside-file" "${ETC_DIR}/planted-link"
# shellcheck disable=SC2329  # called by set_enginescript_etc_permissions
chown() { echo "$*" >> "${TEST_ASSET_DIR}/chown-calls"; }
ES_ETC_DIR="${ETC_DIR}" set_enginescript_etc_permissions
unset -f chown
if [[ ! -e "${ETC_DIR}/planted-link" && ! -L "${ETC_DIR}/planted-link" && "$(stat -c %a "${TEST_ASSET_DIR}/outside-file")" == "600" ]]; then
  pass "set_enginescript_etc_permissions removes a planted link and leaves its target alone"
else
  fail "set_enginescript_etc_permissions kept a planted link, or changed its target"
fi
if [[ "$(stat -c %a "${ETC_DIR}")$(stat -c %a "${ETC_DIR}/install-state.conf")$(stat -c %a "${ETC_DIR}/uptimerobot.conf")" == "755644640" ]]; then
  pass "the folder is 755, the install state 644, and the Uptime Robot key 640"
else
  fail "modes are $(stat -c %a "${ETC_DIR}") $(stat -c %a "${ETC_DIR}/install-state.conf") $(stat -c %a "${ETC_DIR}/uptimerobot.conf")"
fi
if [[ "$(head -n 1 "${TEST_ASSET_DIR}/chown-calls")" == "root:root ${ETC_DIR}" ]] \
    && grep -qx -- "-R root:root ${ETC_DIR}" "${TEST_ASSET_DIR}/chown-calls" \
    && [[ "$(tail -n 1 "${TEST_ASSET_DIR}/chown-calls")" == "root:www-data ${ETC_DIR}/uptimerobot.conf" ]]; then
  pass "the folder goes to root first, then everything in it; www-data keeps read access to the Uptime Robot key only"
else
  fail "chown calls were: $(tr '\n' ';' < "${TEST_ASSET_DIR}/chown-calls")"
fi
if ES_ETC_DIR="${TEST_ASSET_DIR}/no-such-folder" set_enginescript_etc_permissions; then
  pass "set_enginescript_etc_permissions does nothing without the folder"
else
  fail "set_enginescript_etc_permissions failed without the folder"
fi

# run_install_step: a failed step stops the install; a completed step is skipped
# shellcheck disable=SC2034 # read by debug_pause
DEBUG_INSTALL=0
STEP_DIR="${TEST_ASSET_DIR}/steps"
mkdir -p "${STEP_DIR}"
printf '#!/usr/bin/env bash\nexit 0\n' > "${STEP_DIR}/succeeds.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "${STEP_DIR}/fails.sh"
chmod +x "${STEP_DIR}/succeeds.sh" "${STEP_DIR}/fails.sh"

# The step's errors go to the step error log (run_step)
ES_STEP_ERROR_LOG="${STEP_DIR}/step-errors.log"

if (run_install_step "TEST_STEP_SUCCEEDS" "${STEP_DIR}/succeeds.sh" "Succeeding step"; echo "continued") > "${STEP_DIR}/out" 2>&1 \
    && grep -qx "continued" "${STEP_DIR}/out"; then
  pass "run_install_step continues after a step that succeeds"
else
  fail "run_install_step did not continue after a step that succeeds"
fi
assert_state_value "TEST_STEP_SUCCEEDS" "1"
if (run_install_step "TEST_STEP_SUCCEEDS_TOO" "${STEP_DIR}/succeeds.sh" "Succeeding step"; [[ "${TEST_STEP_SUCCEEDS_TOO:-}" == "1" ]]) > /dev/null 2>&1; then
  pass "run_install_step sets the flag in the running install too, so a later check sees it"
else
  fail "run_install_step left the flag unset in the running install"
fi

if (run_install_step "TEST_STEP_FAILS" "${STEP_DIR}/fails.sh" "Failing step"; echo "continued") > "${STEP_DIR}/out" 2>&1; then
  fail "run_install_step returned success after a step that failed"
elif grep -qx "continued" "${STEP_DIR}/out"; then
  fail "run_install_step carried on after a step that failed"
else
  pass "run_install_step stops the install when a step fails"
fi
if grep -q "^TEST_STEP_FAILS=1$" "${ENGINESCRIPT_INSTALL_STATE_FILE}"; then
  fail "run_install_step set the flag of a step that failed"
else
  pass "run_install_step leaves the flag of a failed step unset, so es.install runs it again"
fi

# run_step: the command's errors go to the step log and on to the install error log, and its
# exit status comes back
printf '#!/usr/bin/env bash\necho "step stderr" >&2\nexit 3\n' > "${STEP_DIR}/noisy.sh"
chmod +x "${STEP_DIR}/noisy.sh"
set +e
run_step "Noisy step" "${STEP_DIR}/noisy.sh" 2> /dev/null
STEP_STATUS=$?
set -e
if [[ "${STEP_STATUS}" -eq 3 ]]; then
  pass "run_step returns the command's exit status"
else
  fail "run_step returned ${STEP_STATUS}, expected 3"
fi
if [[ ! -s "${ES_STEP_ERROR_LOG}" ]]; then
  pass "run_step empties the step log for the next step"
else
  fail "run_step left errors in the step log"
fi

# The site list helpers (es_sites, es_site_add, es_site_remove)
ES_SITES_LIST="${STEP_DIR}/sites.sh"
printf '# The server sites\nSITES=(\n)\n' > "${ES_SITES_LIST}"
es_site_add "example.com"
es_site_add "my-site.co.uk"
es_site_add "example.com"
SITES=()
es_sites
if [[ "${SITES[*]}" == "my-site.co.uk example.com" ]]; then
  pass "es_site_add adds each domain once, and es_sites reads them back"
else
  fail "es_sites read '${SITES[*]}'"
fi
if es_site_exists "example.com" && ! es_site_exists "example.co" && ! es_site_exists "exampleXcom"; then
  pass "es_site_exists matches the exact domain only"
else
  fail "es_site_exists matched the wrong domains"
fi
if ! es_site_add 'bad"domain' 2> /dev/null && ! es_site_add 'a b.com' 2> /dev/null; then
  pass "es_site_add refuses a name that is not a domain"
else
  fail "es_site_add accepted a name that is not a domain"
fi
es_site_add "examplexcom"
es_site_remove "example.com"
SITES=()
es_sites
if ! es_site_exists "example.com" && es_site_exists "my-site.co.uk" && grep -q 'examplexcom' "${ES_SITES_LIST}"; then
  pass "es_site_remove removes the exact domain only (a dot is not a wildcard)"
else
  fail "es_site_remove: the list is now '$(tr '\n' ' ' < "${ES_SITES_LIST}")'"
fi
if (ES_SITES_LIST="${STEP_DIR}/missing.sh"; es_sites; [[ "${#SITES[@]}" -eq 0 ]]); then
  pass "es_sites gives an empty list when there is no site list"
else
  fail "es_sites without a site list"
fi

# install_beside: a build that succeeds replaces the folder; one that fails leaves it as it was
TOOL_DIR="${STEP_DIR}/tools/demo"
mkdir -p "${TOOL_DIR}"
echo "old" > "${TOOL_DIR}/index.php"
echo "stale" > "${TOOL_DIR}/removed-file.php"
# shellcheck disable=SC2329  # called by install_beside
build_ok() { echo "new" > "$1/index.php"; }
# shellcheck disable=SC2329
build_fails() { echo "partial" > "$1/index.php"; return 1; }
if ! install_beside "${TOOL_DIR}" "Demo" build_fails 2> /dev/null && grep -qx "old" "${TOOL_DIR}/index.php" \
    && [[ -z "$(find "${STEP_DIR}/tools" -mindepth 1 -maxdepth 1 -name '.*')" ]]; then
  pass "install_beside keeps the installed copy, and no staging folder, when the build fails"
else
  fail "install_beside changed the installed copy, or left a staging folder, after a failed build"
fi
if install_beside "${TOOL_DIR}" "Demo" build_ok && grep -qx "new" "${TOOL_DIR}/index.php" \
    && [[ ! -e "${TOOL_DIR}/removed-file.php" && -z "$(find "${STEP_DIR}/tools" -mindepth 1 -maxdepth 1 -name '.*')" ]]; then
  pass "install_beside swaps in the new copy, without files the new version no longer has"
else
  fail "install_beside did not swap in the new copy cleanly"
fi
if install_beside "${STEP_DIR}/tools/fresh" "Fresh" build_ok && grep -qx "new" "${STEP_DIR}/tools/fresh/index.php"; then
  pass "install_beside also installs where there was nothing yet"
else
  fail "install_beside failed on a first install"
fi

# acquire_lock: a second holder is refused, the holder's own child processes are not
# shellcheck disable=SC2034  # read by acquire_lock
ES_LOCK_DIR="${STEP_DIR}"
if (acquire_lock "test" && ! (unset ES_LOCK_HELD_test; acquire_lock "test") 2> /dev/null && bash -c 'source "$1"; acquire_lock test' _ "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"); then
  pass "acquire_lock refuses a second run, and lets a script the holder starts through"
else
  fail "acquire_lock did not refuse a second run, or blocked the holder's own child"
fi
if (acquire_lock "test"); then
  pass "acquire_lock is free again once its holder has exited"
else
  fail "acquire_lock stayed held after its holder exited"
fi
unset ES_LOCK_DIR

# shellcheck disable=SC2034 # read by run_install_step through ${!flag_name}
TEST_STEP_DONE=1
if (run_install_step "TEST_STEP_DONE" "${STEP_DIR}/fails.sh" "Completed step") > /dev/null 2>&1; then
  pass "run_install_step skips a step that is already complete"
else
  fail "run_install_step ran a step that is already complete"
fi

# clear_site_nginx_cache: one site's pages go, on both of its names; other sites keep theirs
CACHE_DIR="${STEP_DIR}/nginx-cache"
mkdir -p "${CACHE_DIR}/a/1" "${CACHE_DIR}/b/2"
printf 'header\nKEY: httpsGETexample.com/about/\n' > "${CACHE_DIR}/a/1/bare"
printf 'header\nKEY: httpsGETwww.example.com/\n' > "${CACHE_DIR}/a/1/www"
printf 'header\nKEY: httpsGETstaging.example.com/\n' > "${CACHE_DIR}/b/2/staging"
printf 'header\nKEY: httpsGETexample.com.au/\n' > "${CACHE_DIR}/b/2/other-tld"
printf 'header\nKEY: httpsGETexampleXcom/\n' > "${CACHE_DIR}/b/2/dot-literal"
ES_NGINX_CACHE_DIR="${CACHE_DIR}" clear_site_nginx_cache "example.com"
CACHE_LEFT="$(cd "${CACHE_DIR}" && find . -type f -printf '%f\n' | sort | tr '\n' ' ')"
if [[ "${CACHE_LEFT}" == "dot-literal other-tld staging " ]]; then
  pass "clear_site_nginx_cache removes the domain's and www.<domain>'s pages only"
else
  fail "clear_site_nginx_cache left '${CACHE_LEFT}' (expected 'dot-literal other-tld staging ')"
fi

# cloudflare_curl: the email and key reach curl on standard input, never on its command line
# shellcheck disable=SC2329  # called by cloudflare_curl
curl() {
  printf '%s\n' "$@" > "${STEP_DIR}/curl-args"
  cat > "${STEP_DIR}/curl-config"
}
CF_ACCOUNT_EMAIL='admin@example.com' CF_GLOBAL_API_KEY='not-a-real-key"\x' \
  cloudflare_curl -s -X GET "https://api.cloudflare.com/client/v4/zones" -H "Content-Type: application/json"
unset -f curl
if ! grep -q "not-a-real-key\|admin@example.com" "${STEP_DIR}/curl-args" \
    && grep -Fxq -- "-K" "${STEP_DIR}/curl-args" \
    && grep -Fxq "https://api.cloudflare.com/client/v4/zones" "${STEP_DIR}/curl-args"; then
  pass "cloudflare_curl keeps the Cloudflare credentials off curl's command line"
else
  fail "cloudflare_curl put the credentials on curl's command line, or dropped the arguments"
fi
# shellcheck disable=SC1003  # the expected backslash escapes, not a quote
CF_EXPECTED_CONFIG='header = "X-Auth-Email: admin@example.com"
header = "X-Auth-Key: not-a-real-key\"\\x"'
if [[ "$(cat "${STEP_DIR}/curl-config")" == "${CF_EXPECTED_CONFIG}" ]]; then
  pass "cloudflare_curl passes the headers as an escaped curl config"
else
  fail "cloudflare_curl passed this config: $(cat "${STEP_DIR}/curl-config")"
fi

echo ""
echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="
echo ""

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
