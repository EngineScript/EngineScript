#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Configuration Review
#----------------------------------------------------------------------------------
# The configuration review at the start of es.install must show every option of the install
# options template. ENGINESCRIPT_SETTING_NAMES and ENGINESCRIPT_CREDENTIAL_NAMES must list each
# option once, in the template's order, with no name the template lacks; es.info and es.debug
# must show the settings and never the credentials.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/config/home/enginescript-install-options.txt"
FAILED=0

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  FAILED=1
}

# Read by enginescript-common.sh
# shellcheck disable=SC2034
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
# shellcheck disable=SC1090
source "${TEMPLATE}"
source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"

mapfile -t OPTIONS < <(sed -n 's/^\([A-Z][A-Z0-9_]*\)=.*/\1/p' "${TEMPLATE}")
[[ "${#OPTIONS[@]}" -gt 0 ]] || {
  echo "FAIL  no options were found in the template"
  exit 1
}
REVIEW="$(print_install_settings 2> /dev/null; print_install_credentials)"
SETTINGS_SOURCE="$(declare -f print_install_settings)"

# Every option is shown, by name or inside one of the backup lines
missing=()
for option in "${OPTIONS[@]}"; do
  if ! grep -q "^${option} = " <<< "${REVIEW}" && ! grep -qF "\${${option}" <<< "${SETTINGS_SOURCE}"; then
    missing+=("${option}")
  fi
done
if [[ "${#missing[@]}" -eq 0 ]]; then
  pass "the review shows all ${#OPTIONS[@]} options of the template"
else
  fail "the review leaves out: ${missing[*]}"
fi

# Each listed name is an option of the template, listed once, in the template's order
check_list() {
  local label="$1"
  shift
  local -a listed=("$@") in_template=() stale=()
  local name option
  for name in "${listed[@]}"; do
    printf '%s\n' "${OPTIONS[@]}" | grep -qx "${name}" || stale+=("${name}")
  done
  for option in "${OPTIONS[@]}"; do
    printf '%s\n' "${listed[@]}" | grep -qx "${option}" && in_template+=("${option}")
  done
  if [[ "${#stale[@]}" -gt 0 ]]; then
    fail "${label} has names the template lacks: ${stale[*]}"
  elif [[ "${listed[*]}" != "${in_template[*]}" ]]; then
    fail "${label} is not in the template's order, or lists a name twice"
  else
    pass "${label}: ${#listed[@]} options, in the template's order"
  fi
}
check_list "ENGINESCRIPT_SETTING_NAMES" "${ENGINESCRIPT_SETTING_NAMES[@]}"
check_list "ENGINESCRIPT_CREDENTIAL_NAMES" "${ENGINESCRIPT_CREDENTIAL_NAMES[@]}"

overlap="$(printf '%s\n' "${ENGINESCRIPT_SETTING_NAMES[@]}" "${ENGINESCRIPT_CREDENTIAL_NAMES[@]}" | sort | uniq -d)"
if [[ -z "${overlap}" ]]; then
  pass "no option is both a setting and a credential"
else
  fail "in both lists: ${overlap//$'\n'/ }"
fi

# The three places that review the options use the lists
INSTALL="${REPO_ROOT}/scripts/install/enginescript-install.sh"
INFO="${REPO_ROOT}/scripts/functions/alias/alias-server-info.sh"
DEBUG="${REPO_ROOT}/scripts/functions/alias/alias-debug.sh"
if grep -q '^print_install_settings$' "${INSTALL}" && grep -q '^print_install_credentials$' "${INSTALL}"; then
  pass "es.install shows the settings and the credentials"
else
  fail "es.install does not call print_install_settings and print_install_credentials"
fi
if grep -q '^print_install_settings$' "${INFO}" && ! grep -q 'print_install_credentials\|ENGINESCRIPT_CREDENTIAL_NAMES' "${INFO}"; then
  pass "es.info shows the settings and no credentials"
else
  fail "es.info does not show the settings, or shows credentials"
fi
if grep -q 'ENGINESCRIPT_SETTING_NAMES\[@\]' "${DEBUG}" && ! grep -q 'print_install_credentials\|ENGINESCRIPT_CREDENTIAL_NAMES' "${DEBUG}"; then
  pass "es.debug shows the settings and no credentials"
else
  fail "es.debug does not show the settings, or shows credentials"
fi

exit "${FAILED}"
