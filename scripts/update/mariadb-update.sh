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

# Remove Old MariaDB Repo
rm -rf /etc/apt/sources.list.d/mariadb.list

# Add New MariaDB Repo
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=${MARIADB_VER} --skip-maxscale

# Upgrade MariaDB
apt update --allow-releaseinfo-change -y
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y'

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
  echo "MARIADB=1" >> /var/log/EngineScript/install-log.txt
else
  echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
  exit 1
fi

# MariaDB Database Upgrade
mariadb-upgrade --force

mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'
