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

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi
print_last_errors
debug_pause "EngineScript Update"

# Remove Old MariaDB Repo
rm -rf /etc/apt/sources.list.d/mariadb.list

# Add New MariaDB Repo
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${MARIADB_VER}" --skip-maxscale 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Repository"

# Upgrade MariaDB
apt update --allow-releaseinfo-change -y 2>> /tmp/enginescript_install_errors.log
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y' 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Installation"

# Ensure MariaDB service always restarts on failure
if grep -q '^Restart=on-abnormal' /lib/systemd/system/mariadb.service; then
  sed -i 's/^Restart=on-abnormal/Restart=always/' /lib/systemd/system/mariadb.service
  systemctl daemon-reload
fi

# Re-apply EngineScript my.cnf template and re-tune
systemctl stop mariadb.service
cp -rf /usr/local/bin/enginescript/config/etc/mysql/my.cnf /etc/mysql/my.cnf

# Tune MariaDB configuration
/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Configuration"

# Restart Service
systemctl daemon-reload
systemctl start mariadb.service

# Check if services are running
# MariaDB Service Check
STATUS="$(systemctl is-active mariadb)"
if [[ "${STATUS}" == "active" ]]; then
  echo "PASSED: MariaDB is running."
else
  echo "FAILED: MariaDB not running. Please diagnose this issue before proceeding."
  exit 1
fi

# MySQL Service Check
STATUS="$(systemctl is-active mysql)"
if [[ "${STATUS}" == "active" ]]; then
  echo "PASSED: MySQL is running."
  echo "MARIADB=1" >> /etc/enginescript/install-state.conf
else
  echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
  exit 1
fi

# MariaDB Database Upgrade
mariadb-upgrade --force 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Database Upgrade"

mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'
