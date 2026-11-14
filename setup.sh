#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [[ "${EUID}" != 0 ]];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

# Check if the server is running on a 64-bit environment. If not, exit.
BIT_TYPE=$(uname -m)

if [[ "${BIT_TYPE}" != 'x86_64' ]];
  then
    echo "EngineScript requires a 64-bit environment to run optimally."
    exit 1
fi

# Check that the server runs a supported Ubuntu LTS release. /etc/os-release is on every Ubuntu
# server; lsb_release is not installed on a minimal one.
SUPPORTED_UBUNTU_VERSIONS=("24.04" "26.04")
LINUX_TYPE="$(. /etc/os-release 2> /dev/null && echo "${NAME:-unknown}")"
UBUNTU_VERSION="$(. /etc/os-release 2> /dev/null && echo "${VERSION_ID:-unknown}")"

if [[ "$(. /etc/os-release 2> /dev/null && echo "${ID:-}")" != "ubuntu" ]]; then
  echo "EngineScript does not support ${LINUX_TYPE}. Please use Ubuntu 24.04 LTS or 26.04 LTS."
  exit 1
fi
echo "Detected Linux type: ${LINUX_TYPE}"

if [[ " ${SUPPORTED_UBUNTU_VERSIONS[*]} " != *" ${UBUNTU_VERSION} "* ]]; then
  echo "ALERT:"
  echo "EngineScript does not support Ubuntu ${UBUNTU_VERSION}. Please use Ubuntu 24.04 LTS or 26.04 LTS."
  exit 1
fi
echo "Current Ubuntu version: ${UBUNTU_VERSION}"

# setup.sh is for a new server: it deletes and clones EngineScript again and purges every Apache
# and PHP 7 and 8 package, PHP-FPM included. Once es.install has completed any step, stop: es.install
# carries on with the steps not done yet, and es.update updates EngineScript. ALIAS is set by
# setup.sh itself; install-log.txt is where installs before May 2026 kept the same flags.
for install_state in /etc/enginescript/install-state.conf /var/log/EngineScript/install-log.txt; do
  if [[ -f "${install_state}" ]] && grep -E '^[A-Z_]+=1$' "${install_state}" | grep -qv '^ALIAS='; then
    echo "ALERT:"
    echo "EngineScript is already installed on this server (see ${install_state})."
    echo "setup.sh is only for a new server, and running it again would remove PHP."
    echo "To finish an install, run: es.install"
    echo "To update EngineScript, run: es.update"
    exit 1
  fi
done

#----------------------------------------------------------------------------
# Start Main Script

# Install required packages for the script
apt-get update --allow-releaseinfo-change -y

core_packages=(
  "apt"
  "bash"
  "boxes"
  "cron"
  "coreutils"
  "curl"
  "dos2unix"
  "git"
  "gzip"
  "nano"
  "needrestart"
  "openssl"
  "pwgen"
  "sed"
  "software-properties-common"
  "tar"
  "tzdata"
  "unattended-upgrades"
  "unzip"
  "wget"
  "zip"
)

apt-get install -qy "${core_packages[@]}" || {
  echo "Error: Unable to install one or more packages. Exiting..."
  exit 1
}

# Check for required commands
required_commands=(
  "apt"
  "boxes"
  "dos2unix"
  "git"
  "nano"
  "wget"
)
for cmd in "${required_commands[@]}"; do
  if ! command -v "${cmd}" &> /dev/null; then
    echo "Error: ${cmd} is not installed. Please install it and try again."
    exit 1
  fi
done

# Configure needrestart if available
if [[ -f "/etc/needrestart/needrestart.conf" ]]; then
  sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
fi

# Upgrade software
apt-get upgrade -y

# Return to /usr/src
cd /usr/src || { echo "Error: Failed to change to /usr/src" >&2; exit 1; }

# Remove existing EngineScript directory if it exists
if [[ -d "/usr/local/bin/enginescript" ]]; then
  rm -rf /usr/local/bin/enginescript
fi

# EngineScript Git Clone (full clone to allow branch switching)
git clone https://github.com/EngineScript/EngineScript.git -b master /usr/local/bin/enginescript
# The clone has LF line ends (.gitattributes) and executable scripts (their mode in git). The daily
# permissions job (cron/permissions.sh) puts line ends, modes, and ownership back if they change.

# Source shared functions now that EngineScript is cloned and ready.
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || {
  echo "Error: Failed to source shared functions from /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh"
  exit 1
}

# Pre-install resource checks so setup fails early on unsupported/misreported systems.
require_basic_system_resources "MEMORY_TOTAL_MB" "CPU_COUNT"

echo "Detected total memory: ${MEMORY_TOTAL_MB} MB"
echo "Detected CPU count: ${CPU_COUNT}"

# Create EngineScript Home Directory
mkdir -p "/home/EngineScript/config-backups/nginx"
mkdir -p "/home/EngineScript/config-backups/php"
mkdir -p "/home/EngineScript/mysql-credentials"
mkdir -p "/home/EngineScript/site-backups"
mkdir -p "/home/EngineScript/sites-list"
mkdir -p "/home/EngineScript/temp/site-export"
mkdir -p "/home/EngineScript/temp/site-import-completed-backups"
mkdir -p "/home/EngineScript/temp/site-import"

# Create /etc/enginescript directory if it doesn't exist
if [[ ! -d "/etc/enginescript" ]]; then
    echo "Creating EngineScript configuration directory..."
    mkdir -p "/etc/enginescript"
    echo "✓ EngineScript configuration directory created"
fi

# Ensure install state file exists
initialize_install_state_file || {
  echo "Error: Failed to initialize EngineScript install state."
  exit 1
}

# Create /var/www/admin/control-panel/ if it doesn't exist
if [[ ! -d "/var/www/admin/control-panel/" ]]; then
    echo "Creating EngineScript admin control panel directory..."
    mkdir -p "/var/www/admin/control-panel"
    echo "✓ EngineScript admin control panel directory created"
fi

# Create /var/www/admin/tools/ if it doesn't exist
if [[ ! -d "/var/www/admin/tools/" ]]; then
    echo "Creating EngineScript admin tools directory..."
    mkdir -p "/var/www/admin/tools"
    echo "✓ EngineScript admin tools directory created"
fi

# Create /var/cache/enginescript/api if it doesn't exist
if [[ ! -d "/var/cache/enginescript/api" ]]; then
    echo "Creating EngineScript dashboard API cache directory..."
    mkdir -p "/var/cache/enginescript/api"
    echo "✓ EngineScript dashboard API cache directory created"
fi
# Ensure correct ownership and permissions for the API cache directory
set_api_cache_permissions

# EngineScript Logs
# Create EngineScript logs
mkdir -p "/var/log/EngineScript"
touch "/var/log/EngineScript/install-error-log.log"
touch "/var/log/EngineScript/vhost-export.log"
touch "/var/log/EngineScript/vhost-import.log"
touch "/var/log/EngineScript/vhost-install.log"
touch "/var/log/EngineScript/vhost-remove.log"
touch "/var/log/EngineScript/enginescript-api.log"
touch "/var/log/EngineScript/enginescript-api-security.log"

# Set proper permissions for EngineScript logs
chown -R www-data:www-data "/var/log/EngineScript"
chmod -R 644 "/var/log/EngineScript"/*.log
set_enginescript_log_permissions

# Logrotate - scheduled jobs' logs only; install logs are kept whole
install_enginescript_logrotate

# Return to /usr/src
cd /usr/src || { echo "Error: Failed to change to /usr/src" >&2; exit 1; }

# Create EngineScript Commands
load_install_state

if [[ "${ALIAS:-0}" = 1 ]] && [[ -x "/usr/local/bin/es.config" ]] && [[ -x "/usr/local/bin/es.install" ]] && [[ -x "/usr/local/bin/es.menu" ]];
  then
    echo "EngineScript command installer has already run"
  else
    if /usr/local/bin/enginescript/scripts/install/alias/enginescript-alias-install.sh; then
      set_install_state "ALIAS" "1"
    else
      echo "Error: Failed to install EngineScript commands."
      exit 1
    fi
fi

# Cleanup
apt-get remove --purge 'apache2*' 'php7*' 'php8*' -y

# Update & Upgrade
apt-get update --allow-releaseinfo-change -y
apt-get upgrade -y

# Set time zone
dpkg-reconfigure tzdata

# Set unattended upgrades
dpkg-reconfigure unattended-upgrades

# Set MOTD
cp -rf /usr/local/bin/enginescript/config/etc/update-motd.d/99-enginescript /etc/update-motd.d/99-enginescript
chmod +x /etc/update-motd.d/99-enginescript
chown root:root /etc/update-motd.d/99-enginescript
dos2unix /etc/update-motd.d/99-enginescript

# Test MOTD
run-parts --test /etc/update-motd.d/
run-parts /etc/update-motd.d/

# HWE kernel. Ubuntu's package name keeps the dot (linux-generic-hwe-24.04); the new kernel is
# used from the reboot at the end of setup. Both flavours install the same kernel and modules; on
# a virtual machine the virtual one leaves out the hardware firmware (about 1 GB), the CPU
# microcode, and the power and USB daemons, which the host takes care of. A container runs on its
# host's kernel, so it gets none.
if systemd-detect-virt --container --quiet; then
  echo "Running in a container ($(systemd-detect-virt --container)): skipping the kernel, which the host provides."
else
  if systemd-detect-virt --vm --quiet; then
    HWE_KERNEL="linux-virtual-hwe-${UBUNTU_VERSION}"
  else
    HWE_KERNEL="linux-generic-hwe-${UBUNTU_VERSION}"
  fi
  if ! apt-get install --install-recommends "${HWE_KERNEL}" -y; then
    echo "Warning: Could not install the HWE kernel (${HWE_KERNEL}). The server keeps its current kernel." >&2
  fi
fi

# Update and upgrade
apt-get update --allow-releaseinfo-change -y
apt-get upgrade -y

# Remove old downloads
rm -rf /usr/src/*.tar.gz*

# Remove old packages
apt-get clean -y
apt-get autoremove --purge -y
apt-get autoclean -y

if [[ -f "/home/EngineScript/enginescript-install-options.txt" ]]; then
  clear
  echo -e "\n\nInitial setup is complete.\n\nProceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
else
  cp -rf /usr/local/bin/enginescript/config/home/enginescript-install-options.txt /home/EngineScript/enginescript-install-options.txt
  clear
  echo -e "\n\nInitial setup is complete.\n\nProceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
fi

# /home/EngineScript holds credentials and backups: root only
set_enginescript_home_permissions

echo -e "The server needs to restart." | boxes -a c -d shell -p a1l2
echo "The server will restart in 1 minute."
echo "Restarting..."
shutdown -r +1
