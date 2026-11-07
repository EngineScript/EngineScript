#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Cloudflare API Results
#----------------------------------------------------------------------------------
# The shared Cloudflare functions (enginescript-cloudflare.sh), run against a curl stand-in:
#   - cf_apply prints one line per call: a check mark when the answer says "success": true
#     (compact or pretty-printed), and otherwise a cross with Cloudflare's error message,
#     counting the failure in CF_FAILED. No settings call may bypass it.
#   - cf_find_dns_record and cf_upsert_dns_record find, add, and update records.
#   - cf_ip_ranges accepts only address ranges, so nothing else reaches Nginx or the firewall.
#   - The email and key reach curl on stdin only.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIBRARY="${REPO_ROOT}/scripts/functions/shared/enginescript-cloudflare.sh"
VHOST="${REPO_ROOT}/scripts/functions/shared/enginescript-shared-vhost.sh"
STAGING="${REPO_ROOT}/scripts/functions/vhost/vhost-staging.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
FAILED=0

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  FAILED=1
}

# shellcheck source=scripts/functions/shared/enginescript-cloudflare.sh
source "${LIBRARY}"

# curl stand-in: prints CF_RESPONSE (or, for a URL listed in CF_RESPONSES_DIR, that file), and
# keeps its arguments and the config it reads from stdin. CF_CURL_FAIL=1 makes it fail.
CF_RESPONSES_DIR="${WORK}/responses"
mkdir -p "${CF_RESPONSES_DIR}"
# shellcheck disable=SC2329  # called by the library
curl() {
  local arg url=""
  printf '%s\n' "$@" > "${WORK}/curl-args"
  printf '%s\n' "$@" >> "${WORK}/curl-log"
  if [[ ! -t 0 ]]; then
    cat > "${WORK}/curl-config"
  fi
  for arg in "$@"; do
    [[ "${arg}" == https://* ]] && url="${arg}"
  done
  if [[ "${CF_CURL_FAIL:-0}" == "1" ]]; then
    return 22
  fi
  if [[ -f "${CF_RESPONSES_DIR}/${url//[^A-Za-z0-9]/_}" ]]; then
    cat "${CF_RESPONSES_DIR}/${url//[^A-Za-z0-9]/_}"
    return 0
  fi
  printf '%s' "${CF_RESPONSE:-}"
}
respond() {
  printf '%s' "$2" > "${CF_RESPONSES_DIR}/${1//[^A-Za-z0-9]/_}"
}
# shellcheck disable=SC2034  # read by cloudflare_curl
CF_ACCOUNT_EMAIL="user@example.com"
# shellcheck disable=SC2034
CF_GLOBAL_API_KEY="key"
CF_FAILED=0

run() {
  CF_RESPONSE="$1"
  set +e
  OUTPUT="$(cf_apply "zone123" "$2" PATCH "/settings/ssl" '{"value":"strict"}')"
  STATUS=$?
  set -e
}

run '{"result":{"id":"ssl","value":"strict"},"success":true,"errors":[],"messages":[]}' "SSL: strict"
if [[ "${STATUS}" -eq 0 && "${OUTPUT}" == "  ✓ SSL: strict" ]]; then
  pass "a compact success prints one check mark line"
else
  fail "compact success: status ${STATUS}, output '${OUTPUT}'"
fi

run $'{\n  "result": {"id": "speed_brain", "value": "on"},\n  "success": true,\n  "errors": []\n}' "Speed Brain: on"
if [[ "${STATUS}" -eq 0 && "${OUTPUT}" == "  ✓ Speed Brain: on" ]]; then
  pass "a pretty-printed success prints one check mark line"
else
  fail "pretty-printed success: status ${STATUS}, output '${OUTPUT}'"
fi

run '{"success":false,"errors":[{"code":1015,"message":"This setting is not available on your plan."}],"messages":[],"result":null}' "0-RTT: on"
if [[ "${STATUS}" -eq 1 && "${OUTPUT}" == "  ✗ 0-RTT: on: This setting is not available on your plan." ]]; then
  pass "a failure prints a cross with Cloudflare's message"
else
  fail "failure: status ${STATUS}, output '${OUTPUT}'"
fi

run '' "IPv6: on"
if [[ "${STATUS}" -eq 1 && "${OUTPUT}" == "  ✗ IPv6: on: no answer from Cloudflare" ]]; then
  pass "no answer prints a cross"
else
  fail "no answer: status ${STATUS}, output '${OUTPUT}'"
fi

CF_FAILED=0
CF_RESPONSE='{"success":false,"errors":[{"message":"x"}]}'
cf_apply "zone123" "a" PATCH "/settings/a" '{}' > /dev/null || true
cf_apply "zone123" "b" PATCH "/settings/b" '{}' > /dev/null || true
CF_RESPONSE='{"success":true}'
cf_apply "zone123" "c" PATCH "/settings/c" '{}' > /dev/null
if [[ "${CF_FAILED}" -eq 2 ]]; then
  pass "failures are counted in CF_FAILED"
else
  fail "CF_FAILED is ${CF_FAILED}, expected 2"
fi

cf_apply "zone123" "d" PATCH "/settings/ipv6" '{"value":"on"}' > /dev/null
if grep -qx 'https://api.cloudflare.com/client/v4/zones/zone123/settings/ipv6' "${WORK}/curl-args" \
  && grep -qx -- '--data' "${WORK}/curl-args" && grep -qx '{"value":"on"}' "${WORK}/curl-args"; then
  pass "the call goes to the zone's path with the body"
else
  fail "curl was called with: $(tr '\n' ' ' < "${WORK}/curl-args")"
fi

if ! grep -q 'key\|user@example.com' "${WORK}/curl-args" \
  && grep -qx 'header = "X-Auth-Key: key"' "${WORK}/curl-config" \
  && grep -qx 'header = "X-Auth-Email: user@example.com"' "${WORK}/curl-config"; then
  pass "the email and key reach curl on stdin, not on its command line"
else
  fail "the credentials were not passed on stdin only"
fi

# Zone and record lookups
CF_RESPONSE=""
respond "https://api.cloudflare.com/client/v4/zones?name=example.com&status=active" '{"result":[{"id":"abc123","name":"example.com"}],"success":true}'
if [[ "$(cf_zone_id example.com)" == "abc123" ]]; then
  pass "cf_zone_id prints the zone's ID"
else
  fail "cf_zone_id printed '$(cf_zone_id example.com)'"
fi
if [[ -z "$(cf_zone_id other.com)" ]]; then
  pass "cf_zone_id prints nothing for a domain with no zone"
else
  fail "cf_zone_id printed something for a domain with no zone"
fi

respond "https://api.cloudflare.com/client/v4/zones/abc123/dns_records?type=A&name=example.com" '{"result":[{"id":"rec1","type":"A","name":"example.com","content":"203.0.113.5"}],"success":true}'
if cf_find_dns_record abc123 example.com A && [[ "${CF_RECORD_ID}" == "rec1" && "${CF_RECORD_TYPE}" == "A" && "${CF_RECORD_CONTENT}" == "203.0.113.5" ]]; then
  pass "cf_find_dns_record sets the record's ID, type, and content"
else
  fail "cf_find_dns_record: '${CF_RECORD_ID}' '${CF_RECORD_TYPE}' '${CF_RECORD_CONTENT}'"
fi
respond "https://api.cloudflare.com/client/v4/zones/abc123/dns_records?name=staging.example.com" '{"result":[],"success":true}'
if cf_find_dns_record abc123 staging.example.com && [[ -z "${CF_RECORD_ID}" ]]; then
  pass "cf_find_dns_record leaves the ID empty when there is no record"
else
  fail "cf_find_dns_record with no record: '${CF_RECORD_ID}'"
fi
if ! CF_CURL_FAIL=1 cf_find_dns_record abc123 example.com A; then
  pass "cf_find_dns_record returns 1 when Cloudflare does not answer"
else
  fail "cf_find_dns_record succeeded without an answer"
fi

# Add or update: POST when there is no record, PUT to the record when there is one
CF_FAILED=0
respond "https://api.cloudflare.com/client/v4/zones/abc123/dns_records?type=CNAME&name=www.example.com" '{"result":[],"success":true}'
CF_RESPONSE='{"success":true}'
: > "${WORK}/curl-log"
OUTPUT="$(cf_upsert_dns_record abc123 CNAME www.example.com "CNAME www" '{"type":"CNAME"}')"
if [[ "${OUTPUT}" == "  ✓ CNAME www, added" ]] && grep -qx 'POST' "${WORK}/curl-log" \
  && grep -qx 'https://api.cloudflare.com/client/v4/zones/abc123/dns_records' "${WORK}/curl-log"; then
  pass "cf_upsert_dns_record adds a missing record"
else
  fail "cf_upsert_dns_record add: '${OUTPUT}'"
fi
respond "https://api.cloudflare.com/client/v4/zones/abc123/dns_records?type=CNAME&name=admin.example.com" '{"result":[{"id":"rec9","type":"CNAME","content":"example.com"}],"success":true}'
: > "${WORK}/curl-log"
OUTPUT="$(cf_upsert_dns_record abc123 CNAME admin.example.com "CNAME admin" '{"type":"CNAME"}')"
if [[ "${OUTPUT}" == "  ✓ CNAME admin, updated" ]] && grep -qx 'PUT' "${WORK}/curl-log" \
  && grep -qx 'https://api.cloudflare.com/client/v4/zones/abc123/dns_records/rec9' "${WORK}/curl-log"; then
  pass "cf_upsert_dns_record updates an existing record"
else
  fail "cf_upsert_dns_record update: '${OUTPUT}'"
fi

# IP ranges: only address ranges pass
respond "https://www.cloudflare.com/ips-v4" $'173.245.48.0/20\n103.21.244.0/22\r\n104.16.0.0/13'
respond "https://www.cloudflare.com/ips-v6" $'2400:cb00::/32\n2606:4700::/32'
if [[ "$(cf_ip_ranges v4)" == $'173.245.48.0/20\n103.21.244.0/22\n104.16.0.0/13' ]]; then
  pass "cf_ip_ranges v4 prints the ranges, one per line, even without a final newline"
else
  fail "cf_ip_ranges v4 printed '$(cf_ip_ranges v4 2>&1)'"
fi
if [[ "$(cf_ip_ranges v6)" == $'2400:cb00::/32\n2606:4700::/32' ]]; then
  pass "cf_ip_ranges v6 prints the ranges"
else
  fail "cf_ip_ranges v6 printed '$(cf_ip_ranges v6 2>&1)'"
fi
for bad in $'173.245.48.0/20\n<html>error</html>' $'173.245.48.0/20\n1.2.3.4/33' $'173.245.48.0/20\n1.2.3.4;' '' ; do
  respond "https://www.cloudflare.com/ips-v4" "${bad}"
  if out="$(cf_ip_ranges v4 2> /dev/null)"; then
    fail "cf_ip_ranges accepted a bad list: $(printf '%q' "${bad}")"
  elif [[ -n "${out}" ]]; then
    fail "cf_ip_ranges printed ranges from a bad list"
  else
    pass "cf_ip_ranges refuses a list with $(printf '%q' "${bad}" | cut -c1-40)"
  fi
done
respond "https://www.cloudflare.com/ips-v6" $'2400:cb00::/32\nfe80::1 deny'
if ! cf_ip_ranges v6 > /dev/null 2>&1; then
  pass "cf_ip_ranges v6 refuses a line that is not a range"
else
  fail "cf_ip_ranges v6 accepted a line that is not a range"
fi
if ! CF_CURL_FAIL=1 cf_ip_ranges v4 > /dev/null 2>&1; then
  pass "cf_ip_ranges returns 1 when the download fails"
else
  fail "cf_ip_ranges succeeded without a download"
fi

# No Cloudflare call puts the key on curl's command line
key_args="$(grep -nE 'X-Auth-(Key|Email):' "${VHOST}" "${STAGING}" || true)"
if [[ -z "${key_args}" ]]; then
  pass "no Cloudflare call passes the key as an argument"
else
  fail "Cloudflare credentials on a command line: ${key_args}"
fi

# Every Cloudflare call goes through the library, and every settings change through cf_apply
raw="$(grep -nE 'api\.cloudflare\.com|cloudflare_curl|curl .*-X (PATCH|PUT|POST)' "${VHOST}" "${STAGING}" || true)"
if [[ -z "${raw}" ]]; then
  pass "no Cloudflare call bypasses the shared functions"
else
  fail "Cloudflare calls outside the shared functions: ${raw}"
fi
raw="$(grep -rnE 'cloudflare\.com/ips' "${REPO_ROOT}/scripts" --include='*.sh' | grep -v "enginescript-cloudflare.sh\|scripts/ci/" || true)"
if [[ -z "${raw}" ]]; then
  pass "Cloudflare's IP ranges are fetched only by cf_ip_ranges"
else
  fail "other IP range fetches: ${raw}"
fi

exit "${FAILED}"
