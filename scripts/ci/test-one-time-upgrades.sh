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

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
