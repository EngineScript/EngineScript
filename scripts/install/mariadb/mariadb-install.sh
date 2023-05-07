#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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
SERVER_MEMORY_TOTAL_017=$(( "$(free -m | awk 'NR==2{printf "%d", $2*0.017 }')" ))

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDLBS|32|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDLBS|64|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 2500 ];
  then
    sed -i "s|SEDMAXCON|${SERVER_MEMORY_TOTAL_017}|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDMAXCON|151|g" /etc/mysql/mariadb.cnf
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

echo ""
echo "============================================================="
echo ""
echo "MariaDB setup completed."
echo ""
echo "============================================================="
echo ""

sleep 2
