#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: NGINX_BLOCK_UNSAFE_FILES
#----------------------------------------------------------------------------------
# With the option on, nginx-misc.sh must switch on each of the six unsafe file rules in
# map-cache.conf, and change no other line. With it off, the file must stay as it is.
# The commands run from nginx-misc.sh itself, on a copy of the map in a temporary directory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
MISC="${REPO_ROOT}/scripts/install/nginx/nginx-misc.sh"
TEMPLATE="${REPO_ROOT}/config/etc/nginx/globals/map-cache.conf"
FAILED=0

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  FAILED=1
}

# The option's block from nginx-misc.sh, pointed at the copy
# shellcheck disable=SC2016  # the pattern matches the literal ${NGINX_BLOCK_UNSAFE_FILES} in the script
sed -n '/^if \[\[ "${NGINX_BLOCK_UNSAFE_FILES}" == "1" \]\]; then$/,/^fi$/p' "${MISC}" \
  | sed "s|/etc/nginx/globals/map-cache.conf|${WORK}/map-cache.conf|" > "${WORK}/block.sh"
[[ -s "${WORK}/block.sh" ]] || {
  echo "FAIL  the option's block was not found in nginx-misc.sh"
  exit 1
}

run_block() {
  cp "${TEMPLATE}" "${WORK}/map-cache.conf"
  NGINX_BLOCK_UNSAFE_FILES="$1" bash -eu "${WORK}/block.sh"
}

if run_block 0 && cmp -s "${TEMPLATE}" "${WORK}/map-cache.conf"; then
  pass "with the option off, map-cache.conf is unchanged"
else
  fail "with the option off, map-cache.conf changed"
fi

if run_block 1; then
  pass "with the option on, the commands exit 0"
else
  fail "with the option on, the commands failed"
fi

for rule in '"~\*\\\.(?:asc' '"~\*(Gemfile' '"~\*(changelog' '"~\*gems\\\.' '"~\*/wp-content/updraft/' '"~\*/wp-content/uploads/\.\*\\\.'; do
  if grep -q "^  ${rule}" "${WORK}/map-cache.conf"; then
    pass "rule switched on: ${rule}"
  else
    fail "rule still off: ${rule}"
  fi
done

changed="$(diff "${TEMPLATE}" "${WORK}/map-cache.conf" | grep -c '^>' || true)"
if [[ "${changed}" -eq 6 ]]; then
  pass "exactly six lines changed"
else
  fail "${changed} lines changed, expected six"
fi

# The two rules that stay off whatever the option says
for rule in '#"~\*/(wp-content)' '#"~\*/wp-content/uploads/enginescript-es-se-site-exports/'; do
  if grep -q "^  ${rule}" "${WORK}/map-cache.conf"; then
    pass "rule left off: ${rule}"
  else
    fail "rule changed: ${rule}"
  fi
done

exit "${FAILED}"
