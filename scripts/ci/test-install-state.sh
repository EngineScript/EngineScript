#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Install State Helpers
#----------------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

SUPPORTED_PHP_VERSIONS=(
  "8.2"
  "8.3"
  "8.4"
  "8.5"
)
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
  "OPENSSL"
  "SWAP"
  "KERNEL_TWEAKS"
  "THP"
  "KSM"
  "SFL"
  "NTP"
  "DO_CONSOLE"
  "PCRE"
  "ZLIB"
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
INSTALL_PHPMYADMIN=1
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0
assert_installation_completion_passes "check_installation_completion passes with all required flags complete"

set_install_state "ADMIN_CONTROL_PANEL" "0"
assert_installation_completion_fails "check_installation_completion fails when ADMIN_CONTROL_PANEL is incomplete"

set_install_state "ADMIN_CONTROL_PANEL" "1"
set_install_state "PHPMYADMIN" "0"
assert_installation_completion_fails "check_installation_completion fails when enabled PHPMYADMIN is incomplete"

INSTALL_PHPMYADMIN=0
assert_installation_completion_passes "check_installation_completion ignores PHPMYADMIN when disabled"

INSTALL_PHPMYADMIN=1
set_install_state "PHPMYADMIN" "1"
set_install_state "WP_CLI" "0"
assert_installation_completion_fails "check_installation_completion fails when WP_CLI is incomplete"

set_install_state "WP_CLI" "1"
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=1
assert_installation_completion_fails "check_installation_completion requires DO_CONSOLE when enabled"

set_install_state "DO_CONSOLE" "1"
assert_installation_completion_passes "check_installation_completion passes when optional DO_CONSOLE is complete"

complete_install_state
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0
set_install_state "ADMIN_CONTROL_PANEL" "0"
set_install_state "PHPMYADMIN" "0"
mkdir -p "$(dirname "${ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH}")" "$(dirname "${ENGINESCRIPT_PHPMYADMIN_PATH}")"
touch "${ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH}" "${ENGINESCRIPT_PHPMYADMIN_PATH}"
assert_installation_completion_passes "check_installation_completion backfills admin frontend flags from older TOOLS installs"
assert_state_value "ADMIN_CONTROL_PANEL" "1"
assert_state_value "PHPMYADMIN" "1"

echo ""
echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="
echo ""

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
