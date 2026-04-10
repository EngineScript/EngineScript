#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <component-name> <timeout-seconds> <install-script-path> <log-path>" >&2
  exit 1
fi

COMPONENT_NAME="$1"
TIMEOUT_SECONDS="$2"
INSTALL_SCRIPT_PATH="$3"
LOG_PATH="$4"
INTEGER_REGEX='^[0-9]+$'
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

if ! touch "$LOG_PATH" 2>/dev/null; then
  echo "Error: log file is not writable: $LOG_PATH" >&2
  exit 1
fi

echo "Installing ${COMPONENT_NAME}..."
echo "Script start time: $(date)" > "$LOG_PATH"

set +e
timeout "$TIMEOUT_SECONDS" \
  sudo env CI_ENVIRONMENT=true DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 \
  bash "$INSTALL_SCRIPT_PATH" 2>&1 | tee -a "$LOG_PATH"
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
  echo "Last 50 lines of output:"
  tail -50 "$LOG_PATH" || echo "Failed to display log file contents: $LOG_PATH"

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
