#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Redis Configuration of Sites and Existing Servers
#----------------------------------------------------------------------------------
# assign_site_redis_database must give each site the lowest Redis database number no other
# site uses, and double "databases" in redis.conf when every number is taken;
# migrate_redis_databases must raise older servers to 128 databases and move sites that share
# a number; migrate_redis_lazy_user_flush must add lazyfree-lazy-user-flush to older servers'
# redis.conf and apply it to the running Redis. Sites are wp-config.php copies of EngineScript's
# template in a temporary sites directory; restart_service and redis-cli are replaced with
# stand-ins that record what they were asked to do.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export ES_REDIS_CONF="${WORK}/redis.conf"
export ES_SITES_ROOT="${WORK}/sites"
TEMPLATE="${REPO_ROOT}/config/var/www/wordpress/wp-config.php"

# redis-cli stand-in: records its arguments, answers OK unless REDIS_DOWN is set
mkdir -p "${WORK}/bin"
export REDIS_CLI_LOG="${WORK}/redis-cli.log"
# --scan prints the keys listed in REDIS_SCAN_KEYS that match its --pattern (a glob)
export REDIS_SCAN_KEYS="${WORK}/scan-keys.txt"
: > "${REDIS_SCAN_KEYS}"
cat > "${WORK}/bin/redis-cli" << 'EOF'
#!/usr/bin/env bash
echo "$*" >> "${REDIS_CLI_LOG}"
[[ -n "${REDIS_DOWN:-}" ]] && exit 1
if [[ " $* " == *" --scan "* ]]; then
  pattern=""
  while [[ $# -gt 0 ]]; do [[ "$1" == "--pattern" ]] && pattern="$2"; shift; done
  while IFS= read -r key; do
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ "${key}" == ${pattern} ]] && echo "${key}"
  done < "${REDIS_SCAN_KEYS}"
  exit 0
fi
echo "OK"
EOF
chmod +x "${WORK}/bin/redis-cli"
export PATH="${WORK}/bin:${PATH}"

# Read by enginescript-common.sh
# shellcheck disable=SC2034
SUPPORTED_PHP_VERSIONS=(
  "8.3"
  "8.4"
  "8.5"
)
source "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"

RESTARTS=0
restart_service() {
  RESTARTS=$((RESTARTS + 1))
}

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

# Start from EngineScript's redis.conf with the given "databases" value and no sites
reset_server() {
  sed "s/^databases .*/databases $1/" "${REPO_ROOT}/config/etc/redis/redis.conf" > "${ES_REDIS_CONF}"
  rm -rf "${ES_SITES_ROOT}"
  mkdir -p "${ES_SITES_ROOT}"
  RESTARTS=0
}

# Create a site from the template; with a number, set it as an older version would have
add_site() {
  mkdir -p "${ES_SITES_ROOT}/$1/html"
  cp "${TEMPLATE}" "${ES_SITES_ROOT}/$1/html/wp-config.php"
  if [[ -n "${2:-}" ]]; then
    sed -i "s/WP_REDIS_DATABASE', 0/WP_REDIS_DATABASE', $2/" "${ES_SITES_ROOT}/$1/html/wp-config.php"
  fi
}

new_site() {
  add_site "$1"
  assign_site_redis_database "${ES_SITES_ROOT}/$1/html/wp-config.php" > /dev/null
}

db_of() {
  get_site_redis_database "${ES_SITES_ROOT}/$1/html/wp-config.php"
}

echo "Template and redis.conf"
check "the template sets WP_REDIS_DATABASE 0" "$(get_site_redis_database "${TEMPLATE}")" "0"
check "redis.conf sets 128 databases" "$(ES_REDIS_CONF="${REPO_ROOT}/config/etc/redis/redis.conf" get_redis_database_count)" "128"

echo "New sites take the lowest free number"
reset_server 128
new_site a.test
new_site b.test
new_site c.test
check "first three sites" "$(db_of a.test) $(db_of b.test) $(db_of c.test)" "0 1 2"
rm -rf "${ES_SITES_ROOT}/b.test"
new_site d.test
check "a site added after a removal takes the freed number" "$(db_of d.test)" "1"
new_site e.test
check "the next site takes the next free number" "$(db_of e.test)" "3"
check "no Redis restart while numbers are free" "${RESTARTS}" "0"
check "databases unchanged" "$(get_redis_database_count)" "128"
assign_site_redis_database "${ES_SITES_ROOT}/e.test/html/wp-config.php" > /dev/null
check "assigning again keeps a site on its own number (it does not count itself)" "$(db_of e.test)" "3"
if grep -q "define( 'WP_REDIS_DATABASE', 3 ); // EngineScript gives each site its own database number" "${ES_SITES_ROOT}/e.test/html/wp-config.php"; then
  pass "only the number changes in wp-config.php"
else
  fail "the WP_REDIS_DATABASE line was changed beyond its number"
fi

echo "All numbers taken: the number of databases doubles"
reset_server 4
for site in s0 s1 s2 s3; do new_site "${site}.test"; done
check "four sites fill four databases" "$(db_of s0.test) $(db_of s1.test) $(db_of s2.test) $(db_of s3.test)" "0 1 2 3"
check "no restart yet" "${RESTARTS}" "0"
new_site s4.test
check "the fifth site gets number 4" "$(db_of s4.test)" "4"
check "databases doubled to 8" "$(get_redis_database_count)" "8"
check "Redis restarted once" "${RESTARTS}" "1"
if grep -qx 'databases 8' "${ES_REDIS_CONF}"; then
  pass "redis.conf has exactly 'databases 8'"
else
  fail "redis.conf 'databases' line is wrong: $(grep '^databases' "${ES_REDIS_CONF}")"
fi

echo "No 'databases' setting: the site keeps its number"
reset_server 128
sed -i '/^databases /d' "${ES_REDIS_CONF}"
add_site x.test
if assign_site_redis_database "${ES_SITES_ROOT}/x.test/html/wp-config.php" > /dev/null 2>&1; then
  fail "assigning without a 'databases' setting should fail"
else
  pass "assigning without a 'databases' setting fails"
fi
check "the site keeps 0" "$(db_of x.test)" "0"

echo "Update from an older version"
# An older server: 3 sites added, one removed, one added (shares 2), and the count of sites
# as databases. "databases 12" checks that the setting is replaced exactly.
reset_server 12
add_site a.test 0
add_site c.test 2
add_site d.test 2
add_site e.test 15
migrate_redis_databases > /dev/null
check "databases raised to 128" "$(get_redis_database_count)" "128"
check "Redis restarted once" "${RESTARTS}" "1"
check "the first site keeps a shared number" "$(db_of c.test)" "2"
check "the other site moves to the lowest free number" "$(db_of d.test)" "1"
check "unshared sites keep their numbers" "$(db_of a.test) $(db_of e.test)" "0 15"
RESTARTS=0
migrate_redis_databases > /dev/null
check "a second run changes nothing" "$(db_of a.test) $(db_of c.test) $(db_of d.test) $(db_of e.test) $(get_redis_database_count) ${RESTARTS}" "0 2 1 15 128 0"

echo "Update on a server with more databases than the minimum"
reset_server 256
add_site a.test 0
add_site b.test 200
add_site c.test 200
migrate_redis_databases > /dev/null
check "databases kept at 256, no restart" "$(get_redis_database_count) ${RESTARTS}" "256 0"
check "the shared number is split" "$(db_of b.test) $(db_of c.test)" "200 1"

echo "Update: a number out of range moves"
reset_server 128
add_site a.test 0
add_site b.test 300
migrate_redis_databases > /dev/null
check "the out-of-range site moves to the lowest free number" "$(db_of b.test)" "1"

echo "Update: lazyfree-lazy-user-flush"
check "the template sets it" "$(grep -c '^lazyfree-lazy-user-flush yes$' "${REPO_ROOT}/config/etc/redis/redis.conf")" "1"
# An older server's redis.conf: the template without the setting
reset_server 128
sed -i '/^lazyfree-lazy-user-flush /d' "${ES_REDIS_CONF}"
: > "${REDIS_CLI_LOG}"
migrate_redis_lazy_user_flush > /dev/null
check "added once" "$(grep -c '^lazyfree-lazy-user-flush yes$' "${ES_REDIS_CONF}")" "1"
check "added right after lazyfree-lazy-user-del" "$(grep -A1 '^lazyfree-lazy-user-del ' "${ES_REDIS_CONF}" | tail -1)" "lazyfree-lazy-user-flush yes"
check "applied to the running Redis over the socket" "$(cat "${REDIS_CLI_LOG}")" "-s /run/redis/redis-server.sock CONFIG SET lazyfree-lazy-user-flush yes"
check "no Redis restart" "${RESTARTS}" "0"
: > "${REDIS_CLI_LOG}"
migrate_redis_lazy_user_flush > /dev/null
check "a second run changes nothing" "$(grep -c '^lazyfree-lazy-user-flush ' "${ES_REDIS_CONF}") $(wc -c < "${REDIS_CLI_LOG}" | tr -d ' ')" "1 0"
# A server where the administrator set it to no: kept
reset_server 128
sed -i 's/^lazyfree-lazy-user-flush yes$/lazyfree-lazy-user-flush no/' "${ES_REDIS_CONF}"
migrate_redis_lazy_user_flush > /dev/null
check "an existing 'no' is kept" "$(grep '^lazyfree-lazy-user-flush ' "${ES_REDIS_CONF}")" "lazyfree-lazy-user-flush no"
# Redis not running: the file still gets the setting
reset_server 128
sed -i '/^lazyfree-lazy-user-flush /d' "${ES_REDIS_CONF}"
if REDIS_DOWN=1 migrate_redis_lazy_user_flush > /dev/null; then
  check "Redis not running: still added to the file" "$(grep -c '^lazyfree-lazy-user-flush yes$' "${ES_REDIS_CONF}")" "1"
else
  fail "migrate_redis_lazy_user_flush failed with Redis not running"
fi

echo "Removing a site: only its own Redis keys are deleted"
reset_server 128
add_site gone.test 3
sed -i -e "s/SEDREDISPREFIX/es_aaaaaaaaaaaa/" -e "s/SEDPREFIX_/abc_/" "${ES_SITES_ROOT}/gone.test/html/wp-config.php"
cat > "${REDIS_SCAN_KEYS}" << 'EOF'
es_aaaaaaaaaaaaabc:options:alloptions
es_aaaaaaaaaaaaabc:posts:12
es_aaaaaaaaaaaaabcd:options:alloptions
es_bbbbbbbbbbbbxyz:options:alloptions
EOF
: > "${REDIS_CLI_LOG}"
flush_site_redis_cache "${ES_SITES_ROOT}/gone.test/html/wp-config.php" > /dev/null
check "scans the site's database for its exact key prefix" "$(grep -c -- '-n 3 --scan --pattern es_aaaaaaaaaaaaabc:\*' "${REDIS_CLI_LOG}")" "1"
check "deletes only the site's keys" "$(grep 'UNLINK' "${REDIS_CLI_LOG}")" "-s /run/redis/redis-server.sock -n 3 UNLINK es_aaaaaaaaaaaaabc:options:alloptions es_aaaaaaaaaaaaabc:posts:12"
check "no FLUSHDB, FLUSHALL, or restart" "$(grep -c 'FLUSH' "${REDIS_CLI_LOG}") ${RESTARTS}" "0 0"
add_site placeholder.test
: > "${REDIS_CLI_LOG}"
flush_site_redis_cache "${ES_SITES_ROOT}/placeholder.test/html/wp-config.php" > /dev/null
check "an unfilled template prefix deletes nothing" "$(grep -c 'UNLINK' "${REDIS_CLI_LOG}")" "0"
if flush_site_redis_cache "${ES_SITES_ROOT}/missing.test/html/wp-config.php" > /dev/null; then
  pass "a missing wp-config.php: nothing to do"
else
  fail "flush_site_redis_cache failed without wp-config.php"
fi
: > "${REDIS_SCAN_KEYS}"

echo "Update without Redis"
reset_server 128
rm -f "${ES_REDIS_CONF}"
if migrate_redis_databases > /dev/null; then
  pass "no redis.conf: databases step does nothing"
else
  fail "migrate_redis_databases failed without redis.conf"
fi
if migrate_redis_lazy_user_flush > /dev/null; then
  pass "no redis.conf: lazy flush step does nothing"
else
  fail "migrate_redis_lazy_user_flush failed without redis.conf"
fi

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
