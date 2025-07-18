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

# Function to create swap file
create_swap_file() {
    local swap_size=$1
    echo "Creating swap file of size ${swap_size}"
    fallocate -l "${swap_size}" /swapfile || {
        echo "Error: Failed to create swap file."
    }
    # Suppress mkswap permission warning in debug mode
    if [[ "${DEBUG_INSTALL}" == "1" ]]; then
      mkswap_output=$(mkswap /swapfile 2>&1)
      echo "$mkswap_output" | grep -v 'insecure permissions 0644, fix with: chmod 0600 /swapfile'
    else
      mkswap /swapfile
    fi
    echo "Setting correct swapfile permissions: chmod 0600"
    chmod 0600 /swapfile || {
        echo "Error: Failed to set swapfile permissions."
    }
    swapon /swapfile || {
        echo "Error: Failed to enable swap."
    }
}

# Function to backup fstab and enable swap on boot
enable_swap_on_boot() {
    echo "Backing up /etc/fstab"
    cp -rf /etc/fstab /etc/fstab.bak || {
        echo "Error: Failed to backup /etc/fstab."
    }
    echo "Enabling swap file on boot"
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab || {
        echo "Error: Failed to update /etc/fstab."
    }
}

# Check if swap file already exists
if swapon --show | grep -q '/swapfile'; then
    echo "Swap file already exists. Skipping creation."
else
    create_swap_file "3G"
fi

enable_swap_on_boot

echo "Ignore any swap errors listed above."
echo "Swap file will be enabled once the server has restarted."
