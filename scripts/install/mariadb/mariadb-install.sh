#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Add MariaDB repository
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=${MARIADB_VER} --skip-maxscale

# Install MariaDB
apt update
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y'

# Update
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh
apt full-upgrade -y
apt dist-upgrade -y

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# MySQL Secure Installation Automated
mysql_secure_installation <<EOF

y
${MARIADB_ADMIN_PASSWORD}
${MARIADB_ADMIN_PASSWORD}
y
y
y
y
EOF

# Copy MariaDB Config
systemctl stop mariadb.service
cp -rf /usr/local/bin/enginescript/etc/mysql/mariadb.cnf /etc/mysql/mariadb.cnf

# Create Logs
touch /var/log/mysql/mysql-error.log
touch /var/log/mysql/mariadb-slow.log
touch /var/log/mysql/mysql.log
chown -R mysql:adm /var/log/mysql/mysql-error.log
chown -R mysql:adm /var/log/mysql/mariadb-slow.log
chown -R mysql:adm /var/log/mysql/mysql.log

# Tune MariaDB
SERVER_MEMORY_TOTAL_024=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.024 }')" ))
SERVER_MEMORY_TOTAL_45="$(free -m | awk 'NR==2{printf "%d", $2*0.45 }')"
SERVER_MEMORY_TOTAL_13="$(free -m | awk 'NR==2{printf "%d", $2*0.13 }')"

# tmp_table_size & max_heap_table_size
sed -i "s|SEDTMPTBLSZ|${SERVER_MEMORY_TOTAL_024}M|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMXHPTBLSZ|${SERVER_MEMORY_TOTAL_024}M|g" /etc/mysql/mariadb.cnf

# Max Connections
# Scales to be near the MariaDB default value on a 4GB server
sed -i "s|SEDMAXCON|${SERVER_MEMORY_TOTAL_05}|g" /etc/mysql/mariadb.cnf

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDLBS|32|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDLBS|64|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDTCS|256|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDTCS|${SERVER_MEMORY_TOTAL_07}|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDTOC|2000|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDTOC|4000|g" /etc/mysql/mariadb.cnf
fi

sed -i "s|SEDMYSQL016PERCENT|${SERVER_MEMORY_TOTAL_016}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL02PERCENT|${SERVER_MEMORY_TOTAL_02}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL03PERCENT|${SERVER_MEMORY_TOTAL_03}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL13PERCENT|${SERVER_MEMORY_TOTAL_13}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL45PERCENT|${SERVER_MEMORY_TOTAL_45}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL80PERCENT|${SERVER_MEMORY_TOTAL_80}|g" /etc/mysql/mariadb.cnf
systemctl start mariadb.service

# Check if services are running
# MariaDB Service Check
STATUS="$(systemctl is-active mariadb)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: MariaDB is running."
else
    echo "FAILED: MariaDB not running. Please diagnose this issue before proceeding."
    exit 1
fi

# MySQL Service Check
STATUS="$(systemctl is-active mysql)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: MySQL is running."
    echo "MARIADB=1" >> /home/EngineScript/install-log.txt
else
    echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
    exit 1
fi

echo ""
echo "============================================================="
echo ""
echo "MariaDB setup completed."
echo ""
echo "============================================================="
echo ""

sleep 2
