#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: Site Archive Builder
#----------------------------------------------------------------------------------
# build_site_archive must write the archive vhost-import.sh reads (manifest.txt,
# database/*.sql.gz, files/*.tar.gz in one stored ZIP) for its owner only, leave out what the
# EngineScript Site Exporter plugin leaves out, and leave nothing behind when it fails. WP-CLI is
# replaced with a stand-in that prints a small dump and the site's addresses. site-archive-zip.py,
# which writes the ZIP, is tested on its own too. Needs python3, zip, and unzip.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export SITE_ARCHIVE_SITES_ROOT="${WORK}/sites"
export SITE_ARCHIVE_ZIP_TOOL="${REPO_ROOT}/scripts/functions/shared/site-archive-zip.py"

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

# The process that runs build_site_archive: the ancestor of the calling process whose parent is
# this script
builder_pid() {
  local pid="${BASHPID}" parent
  while parent="$(ps -o ppid= -p "${pid}" | tr -d ' ')" && [[ -n "${parent}" && "${parent}" != "$$" ]]; do
    pid="${parent}"
  done
  echo "${pid}"
}

# WP-CLI stand-in, called as run_as_www_data wp ...
#   WP_FAIL=1        the dump fails
#   WP_SIGNAL=1      the build is sent SIGTERM while the dump runs
#   WP_NOISE=1       other output comes before the site's addresses, as from a must-use plugin
#   WP_HOME_VALUE    the site's address
#   WP_DB_BYTES      the database's size
WP_FAIL=0
WP_SIGNAL=0
WP_NOISE=0
WP_HOME_VALUE="https://example.com"
WP_DB_BYTES=4096
run_as_www_data() {
  shift
  case "$1 ${2:-}" in
    "db size")
      echo "${WP_DB_BYTES}"
      ;;
    "db export")
      if [[ "${WP_FAIL}" == "1" ]]; then
        return 1
      fi
      if [[ "${WP_SIGNAL}" == "1" ]]; then
        kill -TERM "$(builder_pid)"
      fi
      # shellcheck disable=SC2016  # backticks of SQL, not a command
      printf 'CREATE TABLE `wp_options` (id int);\n-- Dump completed on 2026-11-05  1:05:00\n'
      ;;
    "eval "*)
      if [[ "${WP_NOISE}" == "1" ]]; then
        echo "Notice: output from a must-use plugin in /var/www/x.php on line 3"
      fi
      # A carriage return in a value must not reach the manifest
      printf '\nes-home=%s\r\nes-siteurl=https://example.com\nes-prefix=wp_\n' "${WP_HOME_VALUE}"
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

echo "Free space for the database and the left-out folders"
# 1 GB free: enough for the small site, not for a 4 GB database
# shellcheck disable=SC2329  # called by build_site_archive
site_archive_free_kb() { echo 1048576; }
WP_DB_BYTES=$((4 * 1024 * 1024 * 1024))
lacks "the build stops when the database would not fit" build_site_archive "${SITE}" "${OUT2}" 2> "${WORK}/stderr.txt"
holds "it says the space is short" grep -q "Not enough free space" "${WORK}/stderr.txt"
WP_DB_BYTES=4096
# 80 MB free, and 20 MB in wp-content/cache, which is not archived: the cache must not count
# (it would push the need past 80 MB)
# shellcheck disable=SC2329  # called by build_site_archive
site_archive_free_kb() { echo 81920; }
dd if=/dev/zero of="${ROOT}/wp-content/cache/page/big.bin" bs=1M count=20 status=none
holds "a large wp-content/cache does not count against the space" build_site_archive "${SITE}" "${WORK}/out-cache/a.zip"
rm -f "${ROOT}/wp-content/cache/page/big.bin"
unset -f site_archive_free_kb
source "${REPO_ROOT}/scripts/functions/shared/enginescript-site-archive.sh"

echo "Other output around the site's addresses"
WP_NOISE=1
build_site_archive "${SITE}" "${WORK}/out-noise/a.zip"
check "the address is still the site's" "$(unzip -p "${WORK}/out-noise/a.zip" manifest.txt | grep '^home_url=')" "home_url=https://example.com"
check "the table prefix is still the site's" "$(unzip -p "${WORK}/out-noise/a.zip" manifest.txt | grep '^table_prefix=')" "table_prefix=wp_"
WP_NOISE=0
WP_HOME_VALUE="Notice: not an address"
build_site_archive "${SITE}" "${WORK}/out-bad/a.zip"
check "a value that is not an address is left empty" "$(unzip -p "${WORK}/out-bad/a.zip" manifest.txt | grep '^home_url=')" "home_url="
check "the other values stay" "$(unzip -p "${WORK}/out-bad/a.zip" manifest.txt | grep '^site_url=')" "site_url=https://example.com"
WP_HOME_VALUE="https://example.com"
while IFS='|' read -r value is_url; do
  check "'${value}' is an address" "$(site_address_is_url "${value}" && echo yes || echo no)" "${is_url}"
done << 'EOF'
https://example.com|yes
HTTP://Example.com/blog|yes
example.com|no
Notice: something in /var/www/x.php|no
https://example.com extra|no
|no
EOF

echo "A build stopped by a signal"
WP_SIGNAL=1
lacks "the build stops" build_site_archive "${SITE}" "${WORK}/out-signal/a.zip" 2> /dev/null
check "the signal leaves nothing behind" "$(find "${WORK}/out-signal" -mindepth 1 | wc -l | tr -d ' ')" "0"
WP_SIGNAL=0

echo "Staging folders of builds that were killed"
mkdir -p "${WORK}/out-stale/.site-archive.old/bundle" "${WORK}/out-stale/.site-archive.new"
touch -d '2 days ago' "${WORK}/out-stale/.site-archive.old"
build_site_archive "${SITE}" "${WORK}/out-stale/a.zip"
lacks "one from two days ago is removed" test -e "${WORK}/out-stale/.site-archive.old"
holds "a recent one, which may be a build in progress, is kept" test -d "${WORK}/out-stale/.site-archive.new"

echo "Reading a backup back (Backup Tools)"
holds "a whole archive passes" site_archive_verify "${OUT}"
REZIP="${WORK}/rezip"
cp -r "${EXTRACT}" "${REZIP}"
echo "CREATE TABLE cut short" | gzip > "${DUMP/#${EXTRACT}/${REZIP}}"
(cd "${REZIP}" && zip -0 -r -q "${WORK}/cut-dump.zip" .)
lacks "a dump without its last line fails" site_archive_verify "${WORK}/cut-dump.zip"
rm -rf "${REZIP}"
cp -r "${EXTRACT}" "${REZIP}"
head -c 20 "${FILES}" > "${FILES/#${EXTRACT}/${REZIP}}"
(cd "${REZIP}" && zip -0 -r -q "${WORK}/cut-files.zip" .)
lacks "a files archive cut short fails" site_archive_verify "${WORK}/cut-files.zip"
rm -rf "${REZIP}"
cp -r "${EXTRACT}" "${REZIP}"
echo "format=something-else" > "${REZIP}/manifest.txt"
(cd "${REZIP}" && zip -0 -r -q "${WORK}/other-format.zip" .)
lacks "another format fails" site_archive_verify "${WORK}/other-format.zip"
lacks "a file that is not a ZIP fails" site_archive_verify "${ROOT}/index.php"

echo "Keeping the newest files backups"
BACKUPS="${WORK}/backups/files"
# Two wp-content backups from an older version, three site archives, a dated folder a failed run
# left, one that only holds a killed build's staging folder, and a folder with another name
for day in 2026-01-04 2026-01-11; do
  mkdir -p "${BACKUPS}/${day}"
  echo old > "${BACKUPS}/${day}/${SITE}-wp-content.tar.gz"
done
for day in 2026-01-18 2026-01-25 2026-02-01; do
  mkdir -p "${BACKUPS}/${day}"
  echo new > "${BACKUPS}/${day}/${SITE}-site-archive.zip"
done
mkdir -p "${BACKUPS}/2026-01-20" "${BACKUPS}/2026-02-08/.site-archive.killed/bundle" \
  "${BACKUPS}/2026-02-01/.site-archive.killed/bundle" "${BACKUPS}/notes"
site_archive_prune_backups "${BACKUPS}" "${SITE}" 4
check "four copies are kept, old and new counted together, and the folder with another name" \
  "$(find "${BACKUPS}" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" \
  "2026-01-11 2026-01-18 2026-01-25 2026-02-01 notes "
lacks "a killed build's staging folder is removed from a kept copy" test -e "${BACKUPS}/2026-02-01/.site-archive.killed"
holds "the kept copy still has its archive" test -f "${BACKUPS}/2026-02-01/${SITE}-site-archive.zip"
site_archive_prune_backups "${BACKUPS}" "${SITE}" 10
check "keeping more copies than there are removes nothing" "$(find "${BACKUPS}" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "5"
holds "a folder that does not exist is not an error" site_archive_prune_backups "${WORK}/no-such-folder" "${SITE}" 4

echo "The ZIP tool (site-archive-zip.py)"
TOOL_DIR="${WORK}/tool"
mkdir -p "${TOOL_DIR}"
echo "manifest" > "${TOOL_DIR}/manifest.txt"
echo "0" > "${TOOL_DIR}/ok.status"
echo "1" > "${TOOL_DIR}/failed.status"
echo "outside" > "${WORK}/outside.txt"
# Run in the tool's folder, as build_site_archive runs it in its staging folder
zip_tool() {
  (cd "${TOOL_DIR}" && timeout 20 python3 -I "${SITE_ARCHIVE_ZIP_TOOL}" "$@" 2> /dev/null)
}
# A pipe nothing writes to: opening it blocks, so a tool that reached it would hang until the timeout
mkfifo "${TOOL_DIR}/never.pipe"
set +e
zip_tool stopped.zip "manifest.txt=manifest.txt" "database/x.sql.gz=manifest.txt" "files/x.tar.gz=never.pipe" \
  --status "database/x.sql.gz" failed.status 0
check "a failed dump stops the archive before the files part is read (exit 3)" "$?" "3"
lacks "the stopped archive is removed" test -e "${TOOL_DIR}/stopped.zip"
zip_tool no-status.zip "a.txt=manifest.txt" --status a.txt missing.status 0
check "a missing status file stops the archive (exit 3)" "$?" "3"
zip_tool changed.zip "a.txt=manifest.txt" --status a.txt failed.status 1
check "a status up to the highest accepted passes (exit 0)" "$?" "0"
zip_tool missing-source.zip "a.txt=no-such-file"
check "a source that cannot be read fails (exit 1)" "$?" "1"
lacks "and its archive is removed" test -e "${TOOL_DIR}/missing-source.zip"
zip_tool bad.zip "no-equals-sign"
check "an entry without a source is refused (exit 2)" "$?" "2"
zip_tool up.zip "a.txt=../outside.txt"
check "a source in another folder is refused (exit 2)" "$?" "2"
zip_tool full-path.zip "a.txt=${WORK}/outside.txt"
check "a source given by its full path is refused (exit 2)" "$?" "2"
lacks "and nothing is written" test -e "${TOOL_DIR}/full-path.zip"
zip_tool ../escaped.zip "a.txt=manifest.txt"
check "an output in another folder is refused (exit 2)" "$?" "2"
lacks "and it is not written" test -e "${WORK}/escaped.zip"
zip_tool other-status.zip "a.txt=manifest.txt" --status a.txt ../outside.txt 0
check "a status file in another folder is refused (exit 2)" "$?" "2"
zip_tool slip.zip "../a.txt=manifest.txt"
check "an entry name that would unzip outside its folder is refused (exit 2)" "$?" "2"
zip_tool rooted.zip "/etc/a.txt=manifest.txt"
check "an entry name that starts at / is refused (exit 2)" "$?" "2"
set -e
zip_tool order.zip "manifest.txt=manifest.txt" "database/a.gz=ok.status" "files/b.gz=ok.status"
check "entries are written in the order given, with one entry per folder" \
  "$(unzip -Z -1 "${TOOL_DIR}/order.zip" | tr '\n' ' ')" "manifest.txt database/ database/a.gz files/ files/b.gz "
mkdir -p "${TOOL_DIR}/out"
unzip -q "${TOOL_DIR}/order.zip" -d "${TOOL_DIR}/out"
check "unzipped, files and folders are their owner's only" \
  "$(stat -c '%a' "${TOOL_DIR}/out/manifest.txt" "${TOOL_DIR}/out/database" "${TOOL_DIR}/out/database/a.gz" | tr '\n' ' ')" "600 700 600 "

echo "A folder without WordPress"
mkdir -p "${SITE_ARCHIVE_SITES_ROOT}/empty.example/html"
lacks "the build stops without wp-config.php" build_site_archive "empty.example" "${WORK}/out3/empty.zip" 2> /dev/null
lacks "no archive is written" test -e "${WORK}/out3/empty.zip"

echo "Reading an archive (vhost-import.sh)"
check "the import reads home_url from the manifest" "$(site_archive_manifest_value "${EXTRACT}/manifest.txt" home_url)" "https://example.com"
check "the import reads table_prefix from the manifest" "$(site_archive_manifest_value "${EXTRACT}/manifest.txt" table_prefix)" "wp_"
check "a missing manifest key reads as empty" "$(site_archive_manifest_value "${EXTRACT}/manifest.txt" no_such_key)" ""
printf 'home_url=https://example.com\r\n' > "${WORK}/crlf-manifest.txt"
check "a manifest with CRLF line ends reads without the CR" "$(site_archive_manifest_value "${WORK}/crlf-manifest.txt" home_url)" "https://example.com"
# address|without scheme (the old URLs)|domain the site is served at|has a path|uses www
while IFS='|' read -r address old_urls domain has_path uses_www; do
  check "old URLs of ${address}" "$(site_address_without_scheme "${address}")" "${old_urls}"
  check "domain of ${address}" "$(site_address_domain "${address}")" "${domain}"
  check "${address} has a path" "$(site_address_has_path "${address}" && echo yes || echo no)" "${has_path}"
  check "${address} uses www" "$(site_address_uses_www "${address}" && echo yes || echo no)" "${uses_www}"
done << 'EOF'
https://example.com|example.com|example.com|no|no
http://example.com/|example.com|example.com|no|no
https://www.example.co.uk|www.example.co.uk|example.co.uk|no|yes
https://WWW.example.com/|WWW.example.com|example.com|no|yes
https://example.com/blog/|example.com/blog|example.com|yes|no
https://www.example.com/wp|www.example.com/wp|example.com|yes|yes
HTTPS://Example.COM|Example.COM|example.com|no|no
https://example.com:8443/shop|example.com:8443/shop|example.com|yes|no
https://wwwexample.com|wwwexample.com|wwwexample.com|no|no
example.com|example.com|example.com|no|no
EOF

echo ""
echo "Passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
[[ "${TESTS_FAILED}" -eq 0 ]]
