#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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
curl -sSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=mariadb-${MARIADB_VER} --skip-maxscale

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

# Copy my.cnf file.
# innodb_buffer_pool_size is set to use 50% of total server memory.
# If you wish to dedicate more, change it in /etc/mysql/my.cnf
systemctl stop mariadb.service
mv /var/lib/mysql/ib_log* /root
cp -rf /usr/local/bin/enginescript/etc/mysql/mariadb.cnf /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL50PERCENT|${SERVER_MEMORY_TOTAL_50}|g" /etc/mysql/mariadb.cnf
systemctl start mariadb.service

echo ""
echo "============================================================="
echo ""
echo "MariaDB setup completed."
echo ""
echo "============================================================="
echo ""

sleep 2
