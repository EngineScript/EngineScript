#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Cloudflare API Results
#----------------------------------------------------------------------------------
# cf_api must print one line per Cloudflare call: a check mark when the answer says
# "success": true (compact or pretty-printed), and otherwise a cross with Cloudflare's error
# message, counting the failure in CF_FAILED. No settings call may bypass it. The function is
# taken from enginescript-shared-vhost.sh, with cloudflare_curl from enginescript-common.sh, and
# run against a curl stand-in.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VHOST="${REPO_ROOT}/scripts/functions/shared/enginescript-shared-vhost.sh"
COMMON="${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
FAILED=0

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  FAILED=1
}

sed -n '/^    cf_api() {$/,/^    }$/p' "${VHOST}" > "${WORK}/cf-api.sh"
[[ -s "${WORK}/cf-api.sh" ]] || {
  echo "FAIL  cf_api was not found in enginescript-shared-vhost.sh"
  exit 1
}
# shellcheck disable=SC1091
source "${WORK}/cf-api.sh"
# cf_api passes the credentials through cloudflare_curl
sed -n '/^function cloudflare_curl() {$/,/^}$/p' "${COMMON}" > "${WORK}/cloudflare-curl.sh"
[[ -s "${WORK}/cloudflare-curl.sh" ]] || {
  echo "FAIL  cloudflare_curl was not found in enginescript-common.sh"
  exit 1
}
# shellcheck disable=SC1091
source "${WORK}/cloudflare-curl.sh"

# curl stand-in: prints CF_RESPONSE, and keeps its arguments and the config it reads from stdin
# shellcheck disable=SC2329  # called by cloudflare_curl
curl() {
  printf '%s\n' "$@" > "${WORK}/curl-args"
  cat > "${WORK}/curl-config"
  printf '%s' "${CF_RESPONSE}"
}
# Read by cf_api
# shellcheck disable=SC2034
ZONE_ID="zone123"
# shellcheck disable=SC2034
CF_ACCOUNT_EMAIL="user@example.com"
# shellcheck disable=SC2034
CF_GLOBAL_API_KEY="key"
CF_FAILED=0

run() {
  CF_RESPONSE="$1"
  set +e
  OUTPUT="$(cf_api "$2" PATCH "/settings/ssl" '{"value":"strict"}')"
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
cf_api "a" PATCH "/settings/a" '{}' > /dev/null || true
cf_api "b" PATCH "/settings/b" '{}' > /dev/null || true
CF_RESPONSE='{"success":true}'
cf_api "c" PATCH "/settings/c" '{}' > /dev/null
if [[ "${CF_FAILED}" -eq 2 ]]; then
  pass "failures are counted in CF_FAILED"
else
  fail "CF_FAILED is ${CF_FAILED}, expected 2"
fi

cf_api "d" PATCH "/settings/ipv6" '{"value":"on"}' > /dev/null
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

# No Cloudflare call puts the key on curl's command line
key_args="$(grep -nE 'X-Auth-(Key|Email):' "${VHOST}" "${REPO_ROOT}/scripts/functions/vhost/vhost-staging.sh" || true)"
if [[ -z "${key_args}" ]]; then
  pass "no Cloudflare call passes the key as an argument"
else
  fail "Cloudflare credentials on a command line: ${key_args}"
fi

# Every settings change goes through cf_api, so none prints raw JSON or fails unseen
raw="$(grep -nE 'curl .*-X (PATCH|PUT|POST)' "${VHOST}" | grep -v 'cf_api' || true)"
if [[ -z "${raw}" ]]; then
  pass "no Cloudflare change bypasses cf_api"
else
  fail "Cloudflare changes outside cf_api: ${raw}"
fi

exit "${FAILED}"
