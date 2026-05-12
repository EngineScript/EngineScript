#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# CI Test: SQL Credential Creation
# Tests the database credential generation, validation, and SQL execution
# functions used by vhost-install.sh and vhost-import.sh. It also checks the
# vhost import/export source for the canonical single-archive format contract.
#
# This script sources the shared enginescript-db-credentials.sh library and
# calls the exact same functions that production uses, so any change to
# the credential logic is automatically tested. Archive contract checks are
# intentionally source-level because vhost-import.sh and vhost-export.sh are
# interactive production scripts that require a real WordPress site.
#----------------------------------------------------------------------------------

set -euo pipefail

# CI safety net: if running inside GitHub Actions, re-exec under a timeout so a
# future stall cannot reach the runner's default 6-hour limit.
if [[ "${CI:-}" == "true" && "${_CI_TIMEOUT_GUARD:-}" != "1" ]]; then
  export _CI_TIMEOUT_GUARD=1
  exec timeout 600 "$0" "$@"
fi

# Resolve the repo root relative to this script's location (scripts/ci/)
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Source the shared database credential functions from the repo checkout
source "${REPO_ROOT}/scripts/functions/shared/enginescript-db-credentials.sh" || {
  echo "Error: Failed to source enginescript-db-credentials.sh" >&2
  exit 1
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

assert_file_contains() {
  local file_path="$1"
  local pattern="$2"
  local description="$3"

  if grep -Eq -- "${pattern}" "${file_path}"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}


#----------------------------------------------------------------------------------
# Test 1: vhost-install credential creation methods
#----------------------------------------------------------------------------------
echo ""
echo "======================================================="
echo "  Test 1: vhost-install.sh credential methods"
echo "======================================================="
echo ""

# --- Step 1: Generate random characters ---
echo "Step 1: Source enginescript-variables.txt for random credentials"
source "${REPO_ROOT}/enginescript-variables.txt"

if [[ ${#RAND_CHAR2} -eq 2 ]]; then
  pass "RAND_CHAR2 length is 2 (got '${RAND_CHAR2}')"
else
  fail "RAND_CHAR2 length should be 2, got ${#RAND_CHAR2} ('${RAND_CHAR2}')"
fi

if [[ ${#RAND_CHAR4} -eq 4 && "${RAND_CHAR4}" =~ ^[a-zA-Z0-9]+$ ]]; then
  pass "RAND_CHAR4 length is 4, charset valid (got '${RAND_CHAR4}')"
else
  fail "RAND_CHAR4 invalid: length=${#RAND_CHAR4}, value='${RAND_CHAR4}'"
fi

if [[ ${#RAND_CHAR16} -eq 16 && "${RAND_CHAR16}" =~ ^[a-zA-Z0-9]+$ ]]; then
  pass "RAND_CHAR16 length is 16, charset valid"
else
  fail "RAND_CHAR16 invalid: length=${#RAND_CHAR16}"
fi

if [[ ${#RAND_CHAR32} -eq 32 && "${RAND_CHAR32}" =~ ^[a-zA-Z0-9_]+$ ]]; then
  pass "RAND_CHAR32 length is 32, charset valid"
else
  fail "RAND_CHAR32 invalid: length=${#RAND_CHAR32}"
fi

# --- Step 2: Generate install DB name ---
echo ""
echo "Step 2: generate_install_db_name"
INSTALL_DOMAIN="wordpresstesting.com"
generate_install_db_name "${INSTALL_DOMAIN}" || { fail "generate_install_db_name returned non-zero"; }

if [[ -n "${ES_DB_NAME:-}" ]]; then
  pass "ES_DB_NAME is set: '${ES_DB_NAME}'"
else
  fail "ES_DB_NAME is empty after generate_install_db_name"
fi

if [[ ${#ES_DB_NAME} -le 64 ]]; then
  pass "ES_DB_NAME length (${#ES_DB_NAME}) <= 64 char limit"
else
  fail "ES_DB_NAME length (${#ES_DB_NAME}) exceeds 64 char limit"
fi

# --- Step 3: Validate install credentials ---
echo ""
echo "Step 3: validate_install_credentials"
database_name="${ES_DB_NAME}"
database_user="${RAND_CHAR16}"
database_password="${RAND_CHAR32}"

if validate_install_credentials "${database_user}" "${database_password}" "${INSTALL_DOMAIN}"; then
  pass "validate_install_credentials accepted generated credentials"
else
  fail "validate_install_credentials rejected generated credentials"
fi

# --- Step 4: Write credentials file ---
echo ""
echo "Step 4: write_credentials_file"
INSTALL_CREDS_DIR="$(mktemp -d)"
write_credentials_file "${INSTALL_CREDS_DIR}" "${INSTALL_DOMAIN}" "${database_name}" "${database_user}" "${database_password}"

if [[ -f "${INSTALL_CREDS_DIR}/${INSTALL_DOMAIN}.txt" ]]; then
  pass "Credentials file created at ${INSTALL_CREDS_DIR}/${INSTALL_DOMAIN}.txt"
else
  fail "Credentials file not found"
fi

if [[ -n "${DB:-}" && -n "${USR:-}" && -n "${PSWD:-}" ]]; then
  pass "DB, USR, PSWD variables set after sourcing credentials file"
else
  fail "DB, USR, or PSWD not set after sourcing credentials file"
fi

if [[ "${DB}" == "${database_name}" && "${USR}" == "${database_user}" && "${PSWD}" == "${database_password}" ]]; then
  pass "Sourced values match written values"
else
  fail "Sourced values do not match written values"
fi

# --- Step 5: Execute SQL ---
echo ""
echo "Step 5: execute_install_sql"
if execute_install_sql "${DB}" "${USR}" "${PSWD}" "${INSTALL_DOMAIN}"; then
  pass "execute_install_sql completed successfully"
else
  fail "execute_install_sql returned non-zero"
fi

# --- Step 6: Verify in MariaDB ---
echo ""
echo "Step 6: Verify database and user in MariaDB"
if sudo mariadb -e "SHOW DATABASES LIKE '${DB}';" | grep -q "${DB}"; then
  pass "Database '${DB}' exists in MariaDB"
else
  fail "Database '${DB}' not found in MariaDB"
fi

if sudo mariadb -e "SELECT User FROM mysql.user WHERE User='${USR}';" | grep -q "${USR}"; then
  pass "User '${USR}' exists in MariaDB"
else
  fail "User '${USR}' not found in MariaDB"
fi

# Clean up temp dir
rm -rf "${INSTALL_CREDS_DIR}"

echo ""
echo "  vhost-install test complete."


#----------------------------------------------------------------------------------
# Test 2: vhost-import credential creation methods
#----------------------------------------------------------------------------------
echo ""
echo "======================================================="
echo "  Test 2: vhost-import.sh credential methods"
echo "======================================================="
echo ""

# --- Step 1: Generate random characters (fresh set) ---
echo "Step 1: Source enginescript-variables.txt for random credentials (fresh)"
source "${REPO_ROOT}/enginescript-variables.txt"

if [[ ${#RAND_CHAR4} -eq 4 && ${#RAND_CHAR16} -eq 16 && ${#RAND_CHAR32} -eq 32 ]]; then
  pass "Fresh RAND_CHAR4/16/32 generated with correct lengths"
else
  fail "Fresh random credentials have incorrect lengths"
fi

# --- Step 2: Domain name construction (import method) ---
echo ""
echo "Step 2: generate_import_db_name"
IMPORT_DOMAIN="importtest.com"
DB_CHARSET="utf8mb4"

generate_import_db_name "${IMPORT_DOMAIN}" || { fail "generate_import_db_name returned non-zero"; }
DB="${ES_DB_NAME}"
USR="${RAND_CHAR16}"
PSWD="${RAND_CHAR32}"
GENERATED_IMPORT_DB="${DB}"
GENERATED_IMPORT_USR="${USR}"
GENERATED_IMPORT_PSWD="${PSWD}"

if [[ -n "${DB}" && "${DB}" == "importtest_${RAND_CHAR4}" ]]; then
  pass "Import DB constructed and assigned like vhost-import.sh: '${DB}'"
else
  fail "Import DB construction unexpected: '${DB}'"
fi

if [[ -n "${USR}" && -n "${PSWD}" ]]; then
  pass "Import USR and PSWD assigned like vhost-import.sh"
else
  fail "Import USR or PSWD was not assigned"
fi

# --- Step 3: Write credentials file ---
echo ""
echo "Step 3: write_credentials_file"
IMPORT_CREDS_DIR="$(mktemp -d)"
write_credentials_file "${IMPORT_CREDS_DIR}" "${IMPORT_DOMAIN}" "${DB}" "${USR}" "${PSWD}"

if [[ -f "${IMPORT_CREDS_DIR}/${IMPORT_DOMAIN}.txt" ]]; then
  pass "Credentials file created"
else
  fail "Credentials file not found"
fi

if [[ "${DB}" == "${GENERATED_IMPORT_DB}" && "${USR}" == "${GENERATED_IMPORT_USR}" && "${PSWD}" == "${GENERATED_IMPORT_PSWD}" ]]; then
  pass "Sourced values preserve generated import credentials"
else
  fail "Sourced values do not preserve generated import credentials"
fi

# --- Step 4: Validate import credentials ---
echo ""
echo "Step 4: validate_import_credentials"
if validate_import_credentials "${DB}" "${USR}" "${PSWD}" "${DB_CHARSET}"; then
  pass "validate_import_credentials accepted generated credentials"
else
  fail "validate_import_credentials rejected generated credentials"
fi

if [[ "${ES_DB_CHARSET_VALIDATED}" == "utf8mb4" ]]; then
  pass "ES_DB_CHARSET_VALIDATED = '${ES_DB_CHARSET_VALIDATED}'"
else
  fail "ES_DB_CHARSET_VALIDATED unexpected: '${ES_DB_CHARSET_VALIDATED}'"
fi

if [[ "${ES_DB_COLLATION}" == "utf8mb4_unicode_ci" ]]; then
  pass "ES_DB_COLLATION = '${ES_DB_COLLATION}'"
else
  fail "ES_DB_COLLATION unexpected: '${ES_DB_COLLATION}'"
fi

# --- Step 5: Execute SQL ---
echo ""
echo "Step 5: execute_import_sql"
if execute_import_sql "${DB}" "${USR}" "${PSWD}" "${ES_DB_CHARSET_VALIDATED}" "${ES_DB_COLLATION}"; then
  pass "execute_import_sql completed successfully"
else
  fail "execute_import_sql returned non-zero"
fi

# --- Step 6: Verify in MariaDB ---
echo ""
echo "Step 6: Verify database and user in MariaDB"
if sudo mariadb -e "SHOW DATABASES LIKE '${DB}';" | grep -q "${DB}"; then
  pass "Database '${DB}' exists in MariaDB"
else
  fail "Database '${DB}' not found in MariaDB"
fi

if sudo mariadb -e "SELECT User FROM mysql.user WHERE User='${USR}';" | grep -q "${USR}"; then
  pass "User '${USR}' exists in MariaDB"
else
  fail "User '${USR}' not found in MariaDB"
fi

# Clean up temp dir
rm -rf "${IMPORT_CREDS_DIR}"

echo ""
echo "  vhost-import test complete."


#----------------------------------------------------------------------------------
# Test 3: vhost import/export single-archive contract
#----------------------------------------------------------------------------------
echo ""
echo "======================================================="
echo "  Test 3: vhost import/export archive contract"
echo "======================================================="
echo ""

IMPORT_SCRIPT="${REPO_ROOT}/scripts/functions/vhost/vhost-import.sh"
EXPORT_SCRIPT="${REPO_ROOT}/scripts/functions/vhost/vhost-export.sh"

assert_file_contains "${EXPORT_SCRIPT}" 'manifest\.txt' "vhost-export documents manifest.txt in the bundle"
assert_file_contains "${EXPORT_SCRIPT}" 'database/<site>_db_<timestamp>\.sql\.gz' "vhost-export documents database/<site>_db_<timestamp>.sql.gz"
assert_file_contains "${EXPORT_SCRIPT}" 'files/<site>_files_<timestamp>\.tar\.gz' "vhost-export documents files/<site>_files_<timestamp>.tar.gz"
assert_file_contains "${EXPORT_SCRIPT}" 'zip -0 -r -q "\$\{COMBINED_EXPORT_PATH\}" \.' "vhost-export stores the already-compressed payloads in the outer ZIP"
assert_file_contains "${EXPORT_SCRIPT}" 'format=enginescript-site-archive' "vhost-export writes the EngineScript archive format marker"
assert_file_contains "${EXPORT_SCRIPT}" 'version=1' "vhost-export writes archive version 1"
assert_file_contains "${EXPORT_SCRIPT}" 'database_path=database/\$\{DB_EXPORT_FILENAME\}\.gz' "vhost-export writes the canonical database manifest path"
assert_file_contains "${EXPORT_SCRIPT}" 'files_archive_path=files/\$\{FILES_EXPORT_FILENAME\}' "vhost-export writes the canonical files manifest path"

assert_file_contains "${IMPORT_SCRIPT}" 'MANIFEST_PATH="\$\{WP_EXTRACTED_PATH\}/manifest\.txt"' "vhost-import requires manifest.txt at the archive root"
assert_file_contains "${IMPORT_SCRIPT}" 'format=enginescript-site-archive' "vhost-import validates the EngineScript archive format marker"
assert_file_contains "${IMPORT_SCRIPT}" 'version=1' "vhost-import validates archive version 1"
assert_file_contains "${IMPORT_SCRIPT}" 'find "\$\{WP_EXTRACTED_PATH\}/database" -maxdepth 1 -type f -name "\*\.sql\.gz"' "vhost-import requires exactly one database/*.sql.gz file"
assert_file_contains "${IMPORT_SCRIPT}" 'find "\$\{WP_EXTRACTED_PATH\}/files" -maxdepth 1 -type f -name "\*\.tar\.gz"' "vhost-import requires exactly one files/*.tar.gz archive"

if grep -Eq 'two_file|SINGLE_ZIP_FILE|WP_ARCHIVE_DIR|DB_IMPORT_DIR|root-directory|database-file' "${IMPORT_SCRIPT}"; then
  fail "vhost-import still contains legacy separate-file import markers"
else
  pass "vhost-import no longer contains legacy separate-file import markers"
fi

echo ""
echo "  vhost import/export archive contract test complete."


#----------------------------------------------------------------------------------
# Summary
#----------------------------------------------------------------------------------
echo ""
echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="
echo ""

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
