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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Function to create swap file
create_swap_file() {
    local swap_size=$1
    echo "Creating swap file of size ${swap_size}"
    fallocate -l "${swap_size}" /swapfile || {
        echo "Error: Failed to create swap file."
    }
    mkswap /swapfile || {
        echo "Error: Failed to set up swap space."
    }
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
