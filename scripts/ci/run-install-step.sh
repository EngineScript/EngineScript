#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <component-name> <timeout-seconds> <install-script-path> <log-path> <expected-script-sha256>" >&2
  exit 1
fi

COMPONENT_NAME="$1"
TIMEOUT_SECONDS="$2"
INSTALL_SCRIPT_PATH="$3"
LOG_PATH="$4"
EXPECTED_SCRIPT_SHA256="$(printf '%s' "$5" | tr '[:upper:]' '[:lower:]')"
INTEGER_REGEX='^[0-9]+$'
SHA256_REGEX='^[a-f0-9]{64}$'
LOG_TAIL_LINES=50
if ! ALLOWED_INSTALL_DIR="$(realpath "$(pwd)/scripts/ci" 2>/dev/null)"; then
  echo "Error: allowed install directory not found or not resolvable: $(pwd)/scripts/ci" >&2
  exit 1
fi
CANONICAL_INSTALL_SCRIPT_PATH=""
# `timeout` returns 124 when the wrapped command times out.
TIMEOUT_EXIT_CODE=124

if ! [[ "$TIMEOUT_SECONDS" =~ $INTEGER_REGEX ]]; then
  echo "Error: timeout must be an integer (seconds): $TIMEOUT_SECONDS" >&2
  exit 1
fi

if [ ! -f "$INSTALL_SCRIPT_PATH" ]; then
  echo "Error: install script not found: $INSTALL_SCRIPT_PATH" >&2
  exit 1
fi

if ! CANONICAL_INSTALL_SCRIPT_PATH="$(realpath "$INSTALL_SCRIPT_PATH" 2>/dev/null)"; then
  echo "Error: unable to resolve install script path: $INSTALL_SCRIPT_PATH" >&2
  exit 1
fi

case "$CANONICAL_INSTALL_SCRIPT_PATH" in
  "$ALLOWED_INSTALL_DIR"/*) ;;
  *)
    echo "Error: install script path must be within $ALLOWED_INSTALL_DIR" >&2
    exit 1
    ;;
esac

if ! ALLOWED_LOG_BASE_DIR="$(realpath "$(pwd)" 2>/dev/null)"; then
  echo "Error: unable to resolve current working directory path" >&2
  exit 1
fi
LOG_PARENT_DIR="$(dirname -- "$LOG_PATH")"
LOG_FILENAME="$(basename -- "$LOG_PATH")"

if [ ! -d "$LOG_PARENT_DIR" ]; then
  echo "Error: log directory does not exist: $LOG_PARENT_DIR" >&2
  exit 1
fi

if ! RESOLVED_LOG_PARENT="$(realpath "$LOG_PARENT_DIR" 2>/dev/null)"; then
  echo "Error: unable to resolve log directory path: $LOG_PARENT_DIR" >&2
  echo "realpath input: $LOG_PARENT_DIR" >&2
  exit 1
fi

case "$RESOLVED_LOG_PARENT" in
  "$ALLOWED_LOG_BASE_DIR"|"$ALLOWED_LOG_BASE_DIR"/*)
    ;;
  *)
    echo "Error: log path must be within $ALLOWED_LOG_BASE_DIR: $LOG_PATH" >&2
    exit 1
    ;;
esac

if [ "$LOG_FILENAME" = "." ] || [ "$LOG_FILENAME" = ".." ]; then
  echo "Error: invalid log file name: $LOG_PATH" >&2
  exit 1
fi

if [ -L "$LOG_PATH" ]; then
  echo "Error: log path must not be a symlink: $LOG_PATH" >&2
  exit 1
fi

if [ -e "$LOG_PATH" ] && [ ! -f "$LOG_PATH" ]; then
  echo "Error: log path must be a regular file: $LOG_PATH" >&2
  exit 1
fi

if [[ ! "$EXPECTED_SCRIPT_SHA256" =~ $SHA256_REGEX ]]; then
  echo "Error: expected script sha256 must be a 64-character hexadecimal string" >&2
  exit 1
fi

if ! touch "$LOG_PATH" 2>/dev/null; then
  echo "Error: log file is not writable: $LOG_PATH" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: sudo is required but not available in PATH" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "Error: sha256sum is required but not available in PATH" >&2
  exit 1
fi

if ! sudo -n true >/dev/null 2>&1; then
  echo "Error: sudo privileges are required to run installation steps non-interactively" >&2
  exit 1
fi

if ! ACTUAL_SCRIPT_SHA256="$(sha256sum "$CANONICAL_INSTALL_SCRIPT_PATH" | awk '{print $1}')"; then
  echo "Error: failed to compute sha256 for install script: $CANONICAL_INSTALL_SCRIPT_PATH" >&2
  exit 1
fi

if [[ "$ACTUAL_SCRIPT_SHA256" != "$EXPECTED_SCRIPT_SHA256" ]]; then
  echo "Error: install script checksum mismatch for $CANONICAL_INSTALL_SCRIPT_PATH" >&2
  echo "Expected: $EXPECTED_SCRIPT_SHA256" >&2
  echo "Actual:   $ACTUAL_SCRIPT_SHA256" >&2
  exit 1
fi

echo "Installing ${COMPONENT_NAME}..."
echo "Script start time: $(date)" > "$LOG_PATH"

set +e
export CI_ENVIRONMENT=true
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
timeout "$TIMEOUT_SECONDS" \
  sudo --preserve-env=CI_ENVIRONMENT --preserve-env=DEBIAN_FRONTEND --preserve-env=NEEDRESTART_MODE --preserve-env=NEEDRESTART_SUSPEND \
  bash "$CANONICAL_INSTALL_SCRIPT_PATH" 2>&1 | tee -a "$LOG_PATH"
PIPE_EXIT_CODES=("${PIPESTATUS[@]}")
SCRIPT_EXIT_CODE="${PIPE_EXIT_CODES[0]}"
TEE_EXIT_CODE="${PIPE_EXIT_CODES[1]}"
set -e

if [ "$SCRIPT_EXIT_CODE" -ne 0 ]; then
  if [ "$SCRIPT_EXIT_CODE" -eq "$TIMEOUT_EXIT_CODE" ]; then
    echo "${COMPONENT_NAME} installation timed out after ${TIMEOUT_SECONDS} seconds"
  else
    echo "${COMPONENT_NAME} installation failed"
  fi
  echo "Exit code: $SCRIPT_EXIT_CODE"
  if [ "$TEE_EXIT_CODE" -ne 0 ]; then
    echo "Log streaming (tee) exit code: $TEE_EXIT_CODE"
  fi
  echo "Script end time: $(date)" >> "$LOG_PATH"
  echo "Last ${LOG_TAIL_LINES} lines of output:"
  if ! tail -n "$LOG_TAIL_LINES" "$LOG_PATH" 2>/dev/null; then
    TAIL_EXIT_CODE=$?
    echo "Failed to display log file contents: $LOG_PATH"
    echo "tail failed with exit code: $TAIL_EXIT_CODE"
  fi

  exit 1
fi

if [ "$TEE_EXIT_CODE" -ne 0 ]; then
  echo "${COMPONENT_NAME} installation completed, but log streaming failed"
  echo "Log streaming (tee) exit code: $TEE_EXIT_CODE"
  echo "Script end time: $(date)" >> "$LOG_PATH"
  exit 1
fi

echo "Script end time: $(date)" >> "$LOG_PATH"
# Ensure installer/log writes are flushed before subsequent CI steps that may read logs
# or create snapshots/caches; this is intentional despite the small performance cost.
sudo sync
echo "${COMPONENT_NAME} installation completed successfully"
