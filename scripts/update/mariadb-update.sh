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

# MariaDB Database Upgrade
mariadb-upgrade --force
