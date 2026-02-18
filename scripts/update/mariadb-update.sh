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

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi

# Remove Old MariaDB Repo
rm -rf /etc/apt/sources.list.d/mariadb.list

# Add New MariaDB Repo
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${MARIADB_VER}" --skip-maxscale

# Upgrade MariaDB
apt update --allow-releaseinfo-change -y
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y'

# Ensure MariaDB service always restarts on failure
if grep -q '^Restart=on-abnormal' /lib/systemd/system/mariadb.service; then
  sed -i 's/^Restart=on-abnormal/Restart=always/' /lib/systemd/system/mariadb.service
  systemctl daemon-reload
fi

# Re-apply EngineScript my.cnf template and re-tune
systemctl stop mariadb.service
cp -rf /usr/local/bin/enginescript/config/etc/mysql/my.cnf /etc/mysql/my.cnf

# Tune MariaDB configuration
/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh

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
  echo "MARIADB=1" >> /var/log/EngineScript/install-log.log
else
  echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
  exit 1
fi

# MariaDB Database Upgrade
mariadb-upgrade --force

mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'
