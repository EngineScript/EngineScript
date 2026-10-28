#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Backup Settings and Scheduler Cron Job
#----------------------------------------------------------------------------------
# resolve_backup_settings must read the BACKUP_* options and translate the per-type switches
# of older options files; install_backup_cron must replace the separate backup cron jobs of
# older installs with one scheduler job. crontab is replaced with a stand-in that keeps the
# table in a file.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "${FAKE_BIN}"' EXIT
export FAKE_CRONTAB="${FAKE_BIN}/crontab.txt"
: > "${FAKE_CRONTAB}"

# crontab stand-in: "crontab -l" prints the table, "crontab -" replaces it
cat > "${FAKE_BIN}/crontab" << 'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-l" ]]; then
  [[ -s "${FAKE_CRONTAB}" ]] || exit 1
  cat "${FAKE_CRONTAB}"
elif [[ "${1:-}" == "-" ]]; then
  cat > "${FAKE_CRONTAB}"
fi
EOF
chmod +x "${FAKE_BIN}/crontab"
export PATH="${FAKE_BIN}:${PATH}"

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

BACKUP_VARS=(BACKUP_DATABASE_FREQUENCY BACKUP_DATABASE_KEEP_DAYS BACKUP_FILES_FREQUENCY
  BACKUP_FILES_KEEP_COPIES BACKUP_CONFIG_FREQUENCY BACKUP_CONFIG_KEEP_DAYS BACKUP_S3
  BACKUP_S3_INCLUDE_CONFIG BACKUP_S3_KEEP_DAYS HOURLY_LOCAL_DATABASE_BACKUP
  DAILY_LOCAL_DATABASE_BACKUP WEEKLY_LOCAL_WPCONTENT_BACKUP INSTALL_S3_BACKUP
  DAILY_S3_DATABASE_BACKUP HOURLY_S3_DATABASE_BACKUP WEEKLY_S3_WPCONTENT_BACKUP)

# Usage: check_settings "<description>" "<assignments>" "<expected resolved values>"
check_settings() {
  local description="$1" assignments="$2" expected="$3" actual
  unset "${BACKUP_VARS[@]}"
  eval "${assignments}"
  resolve_backup_settings 2> /dev/null
  actual="${BACKUP_DATABASE_FREQUENCY}/${BACKUP_DATABASE_KEEP_DAYS} ${BACKUP_FILES_FREQUENCY}/${BACKUP_FILES_KEEP_COPIES} ${BACKUP_CONFIG_FREQUENCY}/${BACKUP_CONFIG_KEEP_DAYS} s3=${BACKUP_S3}/${BACKUP_S3_INCLUDE_CONFIG}/${BACKUP_S3_KEEP_DAYS}"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${description}"
  else
    fail "${description}: got '${actual}', expected '${expected}'"
  fi
}

echo "======================================================="
echo "Backup Settings Tests"
echo "======================================================="

check_settings "New options file (defaults written by the template)" \
  'BACKUP_DATABASE_FREQUENCY=hourly BACKUP_DATABASE_KEEP_DAYS=30 BACKUP_FILES_FREQUENCY=weekly BACKUP_FILES_KEEP_COPIES=4 BACKUP_CONFIG_FREQUENCY=daily BACKUP_CONFIG_KEEP_DAYS=30 BACKUP_S3=0 BACKUP_S3_INCLUDE_CONFIG=0 BACKUP_S3_KEEP_DAYS=30' \
  "hourly/30 weekly/4 daily/30 s3=0/0/30"
check_settings "Old options file, everything on locally" \
  'DAILY_LOCAL_DATABASE_BACKUP=1 HOURLY_LOCAL_DATABASE_BACKUP=1 WEEKLY_LOCAL_WPCONTENT_BACKUP=1 INSTALL_S3_BACKUP=0' \
  "hourly/30 weekly/4 daily/30 s3=0/0/"
check_settings "Old options file, daily database only" \
  'DAILY_LOCAL_DATABASE_BACKUP=1 HOURLY_LOCAL_DATABASE_BACKUP=0 WEEKLY_LOCAL_WPCONTENT_BACKUP=0' \
  "daily/30 off/4 daily/30 s3=0/0/"
check_settings "Old options file, all backups off" \
  'DAILY_LOCAL_DATABASE_BACKUP=0 HOURLY_LOCAL_DATABASE_BACKUP=0 WEEKLY_LOCAL_WPCONTENT_BACKUP=0' \
  "off/30 off/4 daily/30 s3=0/0/"
check_settings "Old options file with S3: S3 on, nothing deleted from S3" \
  'DAILY_LOCAL_DATABASE_BACKUP=1 HOURLY_LOCAL_DATABASE_BACKUP=1 INSTALL_S3_BACKUP=1 DAILY_S3_DATABASE_BACKUP=1' \
  "hourly/30 off/4 daily/30 s3=1/0/"
check_settings "Old options file: AWS CLI installed but every S3 switch off" \
  'DAILY_LOCAL_DATABASE_BACKUP=1 INSTALL_S3_BACKUP=1' \
  "daily/30 off/4 daily/30 s3=0/0/"
check_settings "Invalid values fall back to the defaults" \
  'BACKUP_DATABASE_FREQUENCY=weekly BACKUP_DATABASE_KEEP_DAYS=0 BACKUP_FILES_FREQUENCY=hourly BACKUP_FILES_KEEP_COPIES=abc BACKUP_CONFIG_FREQUENCY=weekly BACKUP_S3=yes BACKUP_S3_KEEP_DAYS=-5' \
  "daily/30 weekly/4 daily/30 s3=0/0/"
check_settings "Settings can be turned off" \
  'BACKUP_DATABASE_FREQUENCY=off BACKUP_FILES_FREQUENCY=off BACKUP_CONFIG_FREQUENCY=off BACKUP_S3=1 BACKUP_S3_INCLUDE_CONFIG=1 BACKUP_S3_KEEP_DAYS=90' \
  "off/30 off/4 off/30 s3=1/1/90"

echo "======================================================="
echo "Backup Scheduler Cron Job Tests"
echo "======================================================="

SCHEDULER="5 * * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash enginescript-backup.sh scheduled >/dev/null 2>&1"
cat > "${FAKE_CRONTAB}" << 'EOF'
*/15 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash wp-cron.sh >/dev/null 2>&1
0 1 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash daily-database-backup.sh >/dev/null 2>&1
5 * * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash hourly-database-backup.sh >/dev/null 2>&1
10 1 * * 0 cd /usr/local/bin/enginescript/scripts/functions/backup; bash weekly-wp-content-backup.sh >/dev/null 2>&1
47 6 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash nginx-backup.sh >/dev/null 2>&1
EOF
install_backup_cron > /dev/null
if grep -qE 'daily-database-backup|hourly-database-backup|weekly-wp-content-backup' "${FAKE_CRONTAB}"; then
  fail "Old backup jobs are still in the crontab"
else
  pass "Old backup jobs removed"
fi
if [[ "$(grep -cxF "${SCHEDULER}" "${FAKE_CRONTAB}")" == "1" ]]; then
  pass "Scheduler job added once"
else
  fail "Scheduler job count: $(grep -cxF "${SCHEDULER}" "${FAKE_CRONTAB}")"
fi
if grep -q 'wp-cron.sh' "${FAKE_CRONTAB}" && grep -q 'nginx-backup.sh' "${FAKE_CRONTAB}"; then
  pass "Other cron jobs kept"
else
  fail "Other cron jobs were removed"
fi
cp "${FAKE_CRONTAB}" "${FAKE_BIN}/before.txt"
output="$(install_backup_cron)"
if [[ -z "${output}" ]] && cmp -s "${FAKE_CRONTAB}" "${FAKE_BIN}/before.txt"; then
  pass "Second run changes nothing"
else
  fail "Second run changed the crontab or printed '${output}'"
fi
: > "${FAKE_CRONTAB}"
install_backup_cron > /dev/null
if [[ "$(cat "${FAKE_CRONTAB}")" == "${SCHEDULER}" ]]; then
  pass "Empty crontab gets the scheduler job"
else
  fail "Empty crontab: '$(cat "${FAKE_CRONTAB}")'"
fi

echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
