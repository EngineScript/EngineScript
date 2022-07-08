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
#curl -sSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=mariadb-${MARIADB_VER} --skip-maxscale

# Install MariaDB
apt update
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y'
apt full-upgrade -y
apt dist-upgrade -y
apt clean -y
apt autoremove --purge -y
apt autoclean -y

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
mv /var/lib/mysql/ib_log* /root
cp -rf /usr/local/bin/enginescript/etc/mysql/mariadb.cnf /etc/mysql/mariadb.cnf

# Tune MariaDB
if [ "${SERVER_MEMORY_TOTAL_80}" -lt 3000 ];
  then
    sed -i "s|SEDTCS|${SERVER_MEMORY_TOTAL_07}|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDTCS|256|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 3000 ];
  then
    sed -i "s|SEDLBS|32|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDLBS|64|g" /etc/mysql/mariadb.cnf
fi

sed -i "s|SEDMYSQL02PERCENT|${SERVER_MEMORY_TOTAL_02}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL03PERCENT|${SERVER_MEMORY_TOTAL_03}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL13PERCENT|${SERVER_MEMORY_TOTAL_13}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL50PERCENT|${SERVER_MEMORY_TOTAL_50}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL80PERCENT|${SERVER_MEMORY_TOTAL_80}|g" /etc/mysql/mariadb.cnf
systemctl start mariadb.service
SEDLBS
echo ""
echo "============================================================="
echo ""
echo "MariaDB setup completed."
echo ""
echo "============================================================="
echo ""

sleep 2
