#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Site Archive Builder
#----------------------------------------------------------------------------------
# build_site_archive must write the archive vhost-import.sh reads (manifest.txt,
# database/*.sql.gz, files/*.tar.gz in one stored ZIP) for its owner only, leave out what the
# EngineScript Site Exporter plugin leaves out, and leave nothing behind when it fails. WP-CLI is
# replaced with a stand-in that prints a small dump and the site's addresses.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export SITE_ARCHIVE_SITES_ROOT="${WORK}/sites"

source "${REPO_ROOT}/scripts/functions/shared/enginescript-site-archive.sh"

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
  local description="$1" actual="$2" expected="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${description}"
  else
    fail "${description} (expected '${expected}', got '${actual}')"
  fi
}

# Usage: holds "<description>" <command> [arguments]
holds() {
  local description="$1"
  shift
  if "$@"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

# Usage: lacks "<description>" <command> [arguments]: passes when the command fails
lacks() {
  local description="$1"
  shift
  if "$@"; then
    fail "${description}"
  else
    pass "${description}"
  fi
}

# WP-CLI stand-in, called as run_as_www_data wp ...; WP_FAIL=1 makes the dump fail
WP_FAIL=0
run_as_www_data() {
  shift
  case "$1" in
    db)
      [[ "${WP_FAIL}" == "1" ]] && return 1
      # shellcheck disable=SC2016  # backticks of SQL, not a command
      printf 'CREATE TABLE `wp_options` (id int);\n-- Dump completed on 2026-11-05  1:05:00\n'
      ;;
    eval)
      # A carriage return in a value must not reach the manifest
      printf 'https://example.com\r\nhttps://example.com\nwp_\n'
      ;;
    *)
      echo "Unexpected WP-CLI command in the test: $*" >&2
      return 1
      ;;
  esac
}

# A small site with the files the archive leaves out
SITE="example.com"
ROOT="${SITE_ARCHIVE_SITES_ROOT}/${SITE}/html"
mkdir -p "${ROOT}/wp-content/uploads" "${ROOT}/wp-content/cache/page" "${ROOT}/wp-content/upgrade" \
  "${ROOT}/.git" "${ROOT}/wp-content/plugins/demo/.svn"
echo "<?php // config" > "${ROOT}/wp-config.php"
echo "<?php // index" > "${ROOT}/index.php"
echo "User-agent: *" > "${ROOT}/robots.txt"
echo "image" > "${ROOT}/wp-content/uploads/photo.jpg"
echo "cached" > "${ROOT}/wp-content/cache/page/index.html"
echo "old" > "${ROOT}/wp-content/upgrade/partial.zip"
echo "ref" > "${ROOT}/.git/HEAD"
echo "entries" > "${ROOT}/wp-content/plugins/demo/.svn/entries"
echo "deny" > "${ROOT}/.HTACCESS"
echo "memory_limit=1G" > "${ROOT}/.user.ini"

echo "======================================================="
echo "Site Archive Builder Tests"
echo "======================================================="

echo "A site archive"
OUT="${WORK}/out/${SITE}-site-archive.zip"
if build_site_archive "${SITE}" "${OUT}" 2> "${WORK}/stderr.txt"; then
  pass "it is built"
else
  fail "it is built ($(cat "${WORK}/stderr.txt"))"
fi
check "only its owner can read it" "$(stat -c %a "${OUT}")" "600"
check "nothing else is left in the output folder" "$(find "${WORK}/out" -mindepth 1 | wc -l | tr -d ' ')" "1"
check "the ZIP stores its entries without compressing them" \
  "$(unzip -Z -v "${OUT}" | grep -c 'compression method:.*none (stored)')" "$(unzip -Z -1 "${OUT}" | wc -l | tr -d ' ')"

EXTRACT="${WORK}/extract"
mkdir -p "${EXTRACT}"
unzip -q "${OUT}" -d "${EXTRACT}"

echo "What vhost-import.sh checks"
if unzip -Z -1 "${OUT}" | grep -Eq '^/|(^|/)\.\.(/|$)'; then
  fail "no entry is absolute or leaves the archive"
else
  pass "no entry is absolute or leaves the archive"
fi
holds "the manifest names the format" grep -Fxq "format=enginescript-site-archive" "${EXTRACT}/manifest.txt"
holds "the manifest is version 1" grep -Fxq "version=1" "${EXTRACT}/manifest.txt"
check "one database dump" "$(find "${EXTRACT}/database" -maxdepth 1 -type f -name "*.sql.gz" | wc -l | tr -d ' ')" "1"
check "one files archive" "$(find "${EXTRACT}/files" -maxdepth 1 -type f -name "*.tar.gz" | wc -l | tr -d ' ')" "1"
DUMP="$(find "${EXTRACT}/database" -name "*.sql.gz")"
FILES="$(find "${EXTRACT}/files" -name "*.tar.gz")"
check "the dump is complete" "$(zcat "${DUMP}" | tail -n 1)" "-- Dump completed on 2026-11-05  1:05:00"

echo "The manifest"
check "the first six keys keep their order" "$(head -n 6 "${EXTRACT}/manifest.txt" | cut -d= -f1 | tr '\n' ' ')" \
  "format version site created_at_utc database_path files_archive_path "
check "it points at the dump" "$(grep '^database_path=' "${EXTRACT}/manifest.txt")" "database_path=database/${DUMP##*/}"
check "it points at the files archive" "$(grep '^files_archive_path=' "${EXTRACT}/manifest.txt")" "files_archive_path=files/${FILES##*/}"
check "it records the home address without control characters" "$(grep '^home_url=' "${EXTRACT}/manifest.txt" | od -c | grep -c '\\r')" "0"
check "it records the table prefix" "$(grep '^table_prefix=' "${EXTRACT}/manifest.txt")" "table_prefix=wp_"
check "it has one line per key" "$(wc -l < "${EXTRACT}/manifest.txt" | tr -d ' ')" "10"

echo "The files archive"
LIST="$(tar -tzf "${FILES}")"
for entry in ./wp-config.php ./index.php ./robots.txt ./wp-content/uploads/photo.jpg ./wp-content/cache/ ./wp-content/upgrade/; do
  holds "keeps ${entry}" grep -Fxq -- "${entry}" <<< "${LIST}"
done
for entry in ./wp-content/cache/page/index.html ./wp-content/upgrade/partial.zip ./.git/HEAD \
    ./wp-content/plugins/demo/.svn/entries ./.HTACCESS ./.user.ini; do
  lacks "leaves out ${entry}" grep -Fxq -- "${entry}" <<< "${LIST}"
done

echo "A failed database export"
WP_FAIL=1
OUT2="${WORK}/out2/${SITE}-site-archive.zip"
lacks "the build stops when the dump fails" build_site_archive "${SITE}" "${OUT2}" 2> /dev/null
check "the failed dump leaves nothing behind" "$(find "${WORK}/out2" -mindepth 1 | wc -l | tr -d ' ')" "0"
WP_FAIL=0

echo "Too little free space"
# shellcheck disable=SC2329  # called by build_site_archive
site_archive_free_kb() { echo 0; }
lacks "the build stops when space is short" build_site_archive "${SITE}" "${OUT2}" 2> "${WORK}/stderr.txt"
holds "it says why" grep -q "Not enough free space" "${WORK}/stderr.txt"
check "the short space leaves nothing behind" "$(find "${WORK}/out2" -mindepth 1 | wc -l | tr -d ' ')" "0"
unset -f site_archive_free_kb
source "${REPO_ROOT}/scripts/functions/shared/enginescript-site-archive.sh"

echo "A folder without WordPress"
mkdir -p "${SITE_ARCHIVE_SITES_ROOT}/empty.example/html"
lacks "the build stops without wp-config.php" build_site_archive "empty.example" "${WORK}/out3/empty.zip" 2> /dev/null
lacks "no archive is written" test -e "${WORK}/out3/empty.zip"

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
