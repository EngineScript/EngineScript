#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Shared Tuning Plan
#----------------------------------------------------------------------------------
# tuning_calculate must give the decided values for common server sizes; tuning.conf and the
# overrides file must be read with the strict KEY=number parser (never sourced); overrides take
# precedence; a re-plan keeps the saved disk benchmark result; tuning_needs_replan must detect a
# missing or old plan, RAM or CPU changes, and a re-tune that did not finish.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export ES_TUNING_CONF="${WORK}/tuning.conf"
export ES_TUNING_OVERRIDES="${WORK}/tuning-overrides.conf"
export ES_TUNING_PENDING="${WORK}/tuning.pending"

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

# Usage: plan_value <memory MB> <CPUs> <cache disk MB> <KEY>
plan_value() {
  tuning_calculate "$1" "$2" "$3" | sed -n "s/^$4=//p"
}

# Usage: check_plan "<label>" <memory MB> <CPUs> <cache disk MB> "KEY=value KEY=value ..."
check_plan() {
  local label="$1" mem="$2" cpus="$3" disk="$4" pair key expected
  for pair in $5; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    check "${label}: ${key}" "$(plan_value "${mem}" "${cpus}" "${disk}" "${key}")" "${expected}"
  done
}

echo "Plan for common DigitalOcean sizes (MemTotal as the kernel reports it)"
check_plan "1 GB, 1 vCPU" 960 1 25000 "PHP_MAX_CHILDREN=3 MARIADB_MAX_CONNECTIONS=33 MARIADB_BUFFER_POOL_MB=192 REDIS_MAXMEMORY_MB=64 OPCACHE_MEMORY_MB=192 OPCACHE_INTERNED_MB=48 OPCACHE_MAX_FILES=20000 MARIADB_ARIA_MB=64 MARIADB_TABLE_CACHE=2000 MARIADB_TMP_TABLE_MB=32 PHP_MEMORY_LIMIT_MB=256 MARIADB_LOG_FILE_MB=96 MARIADB_LOG_BUFFER_MB=32 NGINX_CACHE_ZONE_MB=32 NGINX_CACHE_MAX_MB=1250 PHP_START_SERVERS=2 PHP_MIN_SPARE_SERVERS=1 PHP_MAX_SPARE_SERVERS=3"
check_plan "2 GB, 1 vCPU" 1970 1 51200 "PHP_MAX_CHILDREN=6 MARIADB_MAX_CONNECTIONS=36 MARIADB_BUFFER_POOL_MB=448 REDIS_MAXMEMORY_MB=197 OPCACHE_MEMORY_MB=256 OPCACHE_INTERNED_MB=64 MARIADB_ARIA_MB=96 MARIADB_LOG_FILE_MB=112 NGINX_CACHE_MAX_MB=2560"
check_plan "2 GB, 2 vCPU" 1970 2 51200 "PHP_MAX_CHILDREN=7 MARIADB_MAX_CONNECTIONS=37 MARIADB_BUFFER_POOL_MB=394 MARIADB_LOG_FILE_MB=98"
check_plan "3 GB, 2 vCPU" 2950 2 61440 "MARIADB_ARIA_MB=112 OPCACHE_MEMORY_MB=256 MARIADB_TABLE_CACHE=2000"
check_plan "4 GB, 2 vCPU" 3920 2 81920 "PHP_MAX_CHILDREN=12 MARIADB_MAX_CONNECTIONS=42 MARIADB_BUFFER_POOL_MB=1312 REDIS_MAXMEMORY_MB=392 OPCACHE_MEMORY_MB=384 OPCACHE_MAX_FILES=80000 MARIADB_ARIA_MB=128 MARIADB_TABLE_CACHE=4000 MARIADB_TMP_TABLE_MB=64 PHP_MEMORY_LIMIT_MB=512 MARIADB_LOG_FILE_MB=328 MARIADB_LOG_BUFFER_MB=32 NGINX_CACHE_ZONE_MB=32 NGINX_CACHE_MAX_MB=4096 PHP_START_SERVERS=3 PHP_MIN_SPARE_SERVERS=2 PHP_MAX_SPARE_SERVERS=5"
check_plan "8 GB, 4 vCPU" 7940 4 163840 "PHP_MAX_CHILDREN=24 MARIADB_MAX_CONNECTIONS=54 MARIADB_BUFFER_POOL_MB=3073 REDIS_MAXMEMORY_MB=794 OPCACHE_MEMORY_MB=768 OPCACHE_INTERNED_MB=96 MARIADB_TABLE_CACHE=8000 MARIADB_LOG_FILE_MB=768 MARIADB_LOG_BUFFER_MB=64 NGINX_CACHE_ZONE_MB=64 NGINX_CACHE_MAX_MB=8192"
check_plan "16 GB, 8 vCPU" 16000 8 327680 "PHP_MAX_CHILDREN=48 MARIADB_MAX_CONNECTIONS=78 MARIADB_BUFFER_POOL_MB=6513 REDIS_MAXMEMORY_MB=1600 OPCACHE_MEMORY_MB=1536 OPCACHE_INTERNED_MB=128 OPCACHE_MAX_FILES=320000 MARIADB_ARIA_MB=256 MARIADB_LOG_FILE_MB=1628 NGINX_CACHE_MAX_MB=10240 PHP_START_SERVERS=5 PHP_MIN_SPARE_SERVERS=4 PHP_MAX_SPARE_SERVERS=7"
check_plan "64 GB, 16 vCPU" 64000 16 655360 "REDIS_MAXMEMORY_MB=2048 MARIADB_LOG_FILE_MB=2048 PHP_MAX_CHILDREN=96"

echo "Every plan stays within memory from 2 GB up (1 GB uses swap for the 3-worker floor)"
for spec in "1970 1" "1970 2" "3920 2" "7940 4" "16000 8" "32000 16"; do
  read -r mem cpus <<< "${spec}"
  eval "$(tuning_calculate "${mem}" "${cpus}" 100000 | sed 's/^/local_/')"
  # shellcheck disable=SC2154 # local_* come from the eval
  total=$((192 + mem * 5 / 100 + local_REDIS_MAXMEMORY_MB * 125 / 100 + local_OPCACHE_MEMORY_MB + local_MARIADB_BUFFER_POOL_MB + 160 + local_MARIADB_ARIA_MB + local_MARIADB_MAX_CONNECTIONS + local_PHP_MAX_CHILDREN * 70))
  (( total <= mem )) && pass "${mem} MB, ${cpus} vCPU: budget ${total} MB fits" || fail "${mem} MB, ${cpus} vCPU: budget ${total} MB exceeds RAM"
done

echo "Writing, reading, and overriding the plan"
tuning_write_plan 3920 2 81920
check "tuning.conf written" "$(grep -c '^PHP_MAX_CHILDREN=12$' "${ES_TUNING_CONF}")" "1"
check "tuning.conf is 644" "$(stat -c %a "${ES_TUNING_CONF}")" "644"
tuning_load
check "tuning_get reads the plan" "$(tuning_get MARIADB_BUFFER_POOL_MB)" "1312"
cat > "${ES_TUNING_OVERRIDES}" << 'EOF'
# An administrator's overrides
PHP_MAX_CHILDREN=20
REDIS_MAXMEMORY_MB=$(touch /tmp/es-tuning-pwned)
MARIADB_BUFFER_POOL_MB=2048 ; rm -rf /
not_upper=5
OPCACHE_MEMORY_MB = 512
EOF
tuning_load
check "an override takes precedence" "$(tuning_get PHP_MAX_CHILDREN)" "20"
check "a command substitution is ignored" "$(tuning_get REDIS_MAXMEMORY_MB)" "392"
check "trailing shell code is ignored" "$(tuning_get MARIADB_BUFFER_POOL_MB)" "1312"
check "lowercase keys and spaced lines are ignored" "$(tuning_get OPCACHE_MEMORY_MB) $(tuning_get not_upper)" "384 "
[[ ! -e /tmp/es-tuning-pwned ]] && pass "nothing in the overrides file was executed" || fail "the overrides file was executed"
rm -f "${ES_TUNING_OVERRIDES}"

echo "The saved disk benchmark result survives a re-plan"
tuning_set_value MARIADB_IO_CAPACITY 3500
tuning_write_plan 7940 4 163840
tuning_load
check "MARIADB_IO_CAPACITY kept" "$(tuning_get MARIADB_IO_CAPACITY)" "3500"
check "the plan was recalculated" "$(tuning_get PHP_MAX_CHILDREN)" "24"
tuning_set_value MARIADB_IO_CAPACITY 4000
check "tuning_set_value replaces, not appends" "$(grep -c '^MARIADB_IO_CAPACITY=' "${ES_TUNING_CONF}")" "1"
tuning_set_value "BAD KEY" 5 && fail "tuning_set_value accepted a bad key" || pass "tuning_set_value rejects a bad key"
tuning_set_value GOOD_KEY "5; reboot" && fail "tuning_set_value accepted a bad value" || pass "tuning_set_value rejects a bad value"

echo "When a re-plan is needed"
check "same RAM and CPUs: no re-plan" "$(tuning_needs_replan 7940 4 && echo yes || echo no)" "no"
check "RAM within 5%: no re-plan" "$(tuning_needs_replan 7700 4 && echo yes || echo no)" "no"
check "RAM changed more than 5%: re-plan" "$(tuning_needs_replan 7400 4 && echo yes || echo no)" "yes"
check "droplet resized up: re-plan" "$(tuning_needs_replan 15900 8 && echo yes || echo no)" "yes"
check "CPU count changed: re-plan" "$(tuning_needs_replan 7940 2 && echo yes || echo no)" "yes"
touch "${ES_TUNING_PENDING}"
check "last re-tune did not finish: re-plan" "$(tuning_needs_replan 7940 4 && echo yes || echo no)" "yes"
rm -f "${ES_TUNING_PENDING}"
check "re-tune finished: no re-plan" "$(tuning_needs_replan 7940 4 && echo yes || echo no)" "no"
sed -i 's/^TUNING_VERSION=.*/TUNING_VERSION=0/' "${ES_TUNING_CONF}"
check "older plan version: re-plan" "$(tuning_needs_replan 7940 4 && echo yes || echo no)" "yes"
rm -f "${ES_TUNING_CONF}"
check "no plan yet: re-plan" "$(tuning_needs_replan 7940 4 && echo yes || echo no)" "yes"
if tuning_write_plan 100 1 1000 2> /dev/null; then
  fail "a plan for 100 MB was written"
else
  pass "an unreadable or tiny memory size writes no plan"
fi

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
