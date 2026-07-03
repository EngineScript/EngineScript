#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: PHP Package List Helpers
#----------------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

SUPPORTED_PHP_VERSIONS=(
  "8.2"
  "8.3"
  "8.4"
  "8.5"
)
PHP_VERSION_OVERRIDE=""

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

assert_no_whitespace_items() {
  local description="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "${item}" =~ [[:space:]] ]]; then
      fail "${description}: package item contains whitespace: '${item}'"
      return
    fi
  done

  pass "${description}"
}

assert_contains() {
  local description="$1"
  local expected="$2"
  shift 2
  local item

  for item in "$@"; do
    if [[ "${item}" == "${expected}" ]]; then
      pass "${description}"
      return
    fi
  done

  fail "${description}: missing '${expected}'"
}

assert_not_contains() {
  local description="$1"
  local unexpected="$2"
  shift 2
  local item

  for item in "$@"; do
    if [[ "${item}" == "${unexpected}" ]]; then
      fail "${description}: found '${unexpected}'"
      return
    fi
  done

  pass "${description}"
}

echo ""
echo "======================================================="
echo "  Test: PHP package helper output"
echo "======================================================="
echo ""

mapfile -t php85_packages < <(get_php_packages_array "8.5")
mapfile -t php84_packages < <(get_php_packages_array "8.4")
mapfile -t expanded_php85_packages < <(get_expanded_php_packages_array "8.5")

if [[ ${#php85_packages[@]} -eq 14 ]]; then
  pass "PHP 8.5 base package list has 14 entries"
else
  fail "PHP 8.5 base package list should have 14 entries, got ${#php85_packages[@]}"
fi

if [[ ${#php84_packages[@]} -eq 15 ]]; then
  pass "PHP 8.4 base package list has 15 entries"
else
  fail "PHP 8.4 base package list should have 15 entries, got ${#php84_packages[@]}"
fi

if [[ ${#expanded_php85_packages[@]} -eq 2 ]]; then
  pass "Expanded PHP package list has 2 entries"
else
  fail "Expanded PHP package list should have 2 entries, got ${#expanded_php85_packages[@]}"
fi

assert_no_whitespace_items "PHP 8.5 packages are emitted one per array item" "${php85_packages[@]}"
assert_no_whitespace_items "PHP 8.4 packages are emitted one per array item" "${php84_packages[@]}"
assert_no_whitespace_items "Expanded PHP packages are emitted one per array item" "${expanded_php85_packages[@]}"

assert_contains "PHP 8.5 includes FPM" "php8.5-fpm" "${php85_packages[@]}"
assert_contains "PHP 8.5 includes MySQL extension" "php8.5-mysql" "${php85_packages[@]}"
assert_not_contains "PHP 8.5 omits separate opcache package" "php8.5-opcache" "${php85_packages[@]}"
assert_contains "PHP 8.4 includes separate opcache package" "php8.4-opcache" "${php84_packages[@]}"
assert_contains "Expanded PHP list includes SOAP" "php8.5-soap" "${expanded_php85_packages[@]}"
assert_contains "Expanded PHP list includes SQLite" "php8.5-sqlite3" "${expanded_php85_packages[@]}"

echo ""
echo "======================================================="
echo "  RESULTS: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
echo "======================================================="
echo ""

if [[ ${TESTS_FAILED} -gt 0 ]]; then
  exit 1
fi
