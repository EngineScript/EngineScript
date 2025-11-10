#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

##############################################################################
# EngineScript Metrics Collection Setup
# Purpose: Install and configure metrics collection cron job
# Location: scripts/install/metrics/
# 
# This script:
#   - Creates /var/lib/enginescript/metrics.json
#   - Copies metrics collection script to /usr/local/bin/
#   - Sets proper permissions
#   - Installs cron job for 5-minute intervals
#
##############################################################################

set -e

# Configuration
METRICS_DIR="/var/lib/enginescript"
METRICS_FILE="${METRICS_DIR}/metrics.json"
COLLECT_SCRIPT="/usr/local/bin/enginescript-collect-metrics"
SOURCE_SCRIPT="/usr/local/bin/enginescript/scripts/functions/metrics/collect-metrics.sh"
CRON_JOB_NAME="enginescript-collect-metrics"
CRON_SCHEDULE="*/5 * * * *"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print info messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print error messages
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to print warning messages
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

info "Setting up metrics collection system..."

# Create metrics directory
if [[ ! -d "${METRICS_DIR}" ]]; then
    info "Creating metrics directory: ${METRICS_DIR}"
    mkdir -p "${METRICS_DIR}"
    chmod 755 "${METRICS_DIR}"
else
    info "Metrics directory already exists: ${METRICS_DIR}"
fi

# Initialize metrics file
if [[ ! -f "${METRICS_FILE}" ]]; then
    info "Initializing metrics file: ${METRICS_FILE}"
    echo "[]" > "${METRICS_FILE}"
    chmod 644 "${METRICS_FILE}"
else
    info "Metrics file already exists: ${METRICS_FILE}"
fi

# Copy metrics collection script
if [[ -f "${SOURCE_SCRIPT}" ]]; then
    info "Installing metrics collection script..."
    cp "${SOURCE_SCRIPT}" "${COLLECT_SCRIPT}"
    chmod 755 "${COLLECT_SCRIPT}"
    info "Script installed: ${COLLECT_SCRIPT}"
else
    error "Source script not found: ${SOURCE_SCRIPT}"
fi

# Install cron job
info "Installing cron job (runs every 5 minutes)..."

# Remove existing cron job if present
if crontab -l 2>/dev/null | grep -q "${CRON_JOB_NAME}"; then
    warn "Existing cron job found, removing old entry..."
    (crontab -l 2>/dev/null | grep -v "${CRON_JOB_NAME}") | crontab - || true
fi

# Add new cron job
(crontab -l 2>/dev/null || echo "") | echo "$(crontab -l 2>/dev/null)
${CRON_SCHEDULE} ${COLLECT_SCRIPT} # ${CRON_JOB_NAME}" | crontab - || {
    error "Failed to install cron job"
}

info "Cron job installed successfully"

# Test metrics collection
info "Running initial metrics collection..."
if "${COLLECT_SCRIPT}"; then
    info "Initial collection successful"
else
    error "Initial collection failed"
fi

# Display status
info "Metrics collection setup complete!"
echo ""
echo "Status:"
echo "  Directory:      ${METRICS_DIR}"
echo "  Metrics file:   ${METRICS_FILE}"
echo "  Cron schedule:  ${CRON_SCHEDULE}"
echo "  Script path:    ${COLLECT_SCRIPT}"
echo ""
echo "To view metrics:"
echo "  cat ${METRICS_FILE} | jq ."
echo ""
echo "To test script manually:"
echo "  ${COLLECT_SCRIPT}"
echo ""
