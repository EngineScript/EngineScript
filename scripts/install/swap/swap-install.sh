#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

source /etc/enginescript/install-state.conf
if [[ "${SWAP}" = 1 ]]; then
    echo "SWAP script has already run"
    exit 0
fi

# Function to create swap file
create_swap_file() {
    local swap_size=$1
    echo "Creating swap file of size ${swap_size}"
    fallocate -l "${swap_size}" /swapfile || {
        echo "Error: Failed to create swap file."
    }
    # Root-only before mkswap, which warns about readable swap files
    chmod 0600 /swapfile || {
        echo "Error: Failed to set swapfile permissions."
    }
    mkswap /swapfile
    swapon /swapfile || {
        echo "Error: Failed to enable swap."
    }
}

# Function to back up fstab and enable swap on boot (once)
enable_swap_on_boot() {
    if grep -qE '^/swapfile[[:space:]]' /etc/fstab; then
        echo "The swap file is already in /etc/fstab."
        return
    fi
    echo "Backing up /etc/fstab."
    cp -rf /etc/fstab /etc/fstab.bak || {
        echo "Error: Failed to back up /etc/fstab."
    }
    echo "Enabling swap file on boot."
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab || {
        echo "Error: Failed to update /etc/fstab."
    }
}

# Swap is a safety net: 3 GB on servers with less than 1.5 GB of RAM (where the PHP-FPM worker
# floor can overcommit memory), 4 GB on larger servers
if [[ "$(tuning_detect_memory_mb)" -lt 1536 ]]; then
    SWAP_SIZE="3G"
else
    SWAP_SIZE="4G"
fi

# Check if swap file already exists
if swapon --show | grep -q '/swapfile'; then
    echo "Swap file already exists. Skipping creation."
else
    create_swap_file "${SWAP_SIZE}"
fi

enable_swap_on_boot

# Mark the installation as complete
set_install_state "SWAP" "1"
echo "Swap completed successfully. Script done."
