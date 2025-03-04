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

# Add MariaDB repository
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=${MARIADB_VER} --skip-maxscale

# Install MariaDB
apt update --allow-releaseinfo-change -y
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y'

# Update
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh
apt upgrade -y

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# New MariaDB Secure Method
# Probably safer to do the secure installation manually, as the previous method would break if MariaDB changed anything in the order that they ask questions.

# Set password with `debconf-set-selections` You don't have to enter it in prompt
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MARIADB_ADMIN_PASSWORD}" # new password for the MySQL root user
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MARIADB_ADMIN_PASSWORD}" # repeat password for the MySQL root user

# Remote Connection to Database
sudo mariadb -e "ALTER USER root@localhost IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('${MARIADB_ADMIN_PASSWORD}');"

# Manually Perform Secure Installation
sudo mariadb -e "UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$MARIADB_ADMIN_PASSWORD')) WHERE User='root'";
sudo mariadb << EOFMYSQLSECURE
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOFMYSQLSECURE

# Old MariaDB Secure Method
# MySQL Secure Installation Automated
#mariadb_secure_installation <<EOF

#y
#${MARIADB_ADMIN_PASSWORD}
#${MARIADB_ADMIN_PASSWORD}
#y
#y
#y
#y
#EOF

# Copy MariaDB Config
systemctl stop mariadb.service
cp -rf /usr/local/bin/enginescript/config/etc/mysql/mariadb.cnf /etc/mysql/mariadb.cnf

# Create Logs
touch /var/log/mysql/mysql-error.log
touch /var/log/mysql/mariadb-slow.log
touch /var/log/mysql/mysql.log
chown -R mysql:adm /var/log/mysql/mysql-error.log
chown -R mysql:adm /var/log/mysql/mariadb-slow.log
chown -R mysql:adm /var/log/mysql/mysql.log

# Open Files Limit
sed -i "s|# LimitNOFILE=32768|LimitNOFILE=60556|g" /usr/lib/systemd/system/mariadb.service

# Tune MariaDB
/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh

# Restart Service
systemctl daemon-reload
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
