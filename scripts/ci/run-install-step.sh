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

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Error: timeout must be an integer (seconds): $TIMEOUT_SECONDS" >&2
  exit 1
fi

if [ ! -f "$INSTALL_SCRIPT_PATH" ]; then
  echo "Error: install script not found: $INSTALL_SCRIPT_PATH" >&2
  exit 1
fi

echo "Installing ${COMPONENT_NAME}..."
echo "Script start time: $(date)" | sudo tee "$LOG_PATH"

set +e
timeout "$TIMEOUT_SECONDS" \
  sudo env CI_ENVIRONMENT=true DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 \
  bash "$INSTALL_SCRIPT_PATH" 2>&1 | sudo tee -a "$LOG_PATH"
SCRIPT_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ "$SCRIPT_EXIT_CODE" -ne 0 ]; then
  echo "${COMPONENT_NAME} installation failed or timed out"
  echo "Exit code: $SCRIPT_EXIT_CODE"
  echo "Script end time: $(date)" | sudo tee -a "$LOG_PATH"
  echo "Last 50 lines of output:"
  tail -50 "$LOG_PATH" 2>/dev/null || echo "No log output available"

  if [ "$SCRIPT_EXIT_CODE" -eq 124 ]; then
    echo "${COMPONENT_NAME} installation timed out after ${TIMEOUT_SECONDS} seconds"
  fi

  exit 1
fi

echo "Script end time: $(date)" | sudo tee -a "$LOG_PATH"
sudo sync
echo "${COMPONENT_NAME} installation completed successfully"
