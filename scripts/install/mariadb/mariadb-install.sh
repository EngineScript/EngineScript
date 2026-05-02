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

source /etc/enginescript/install-state.conf
if [[ "${MARIADB}" = 1 ]]; then
    echo "MARIADB script has already run"
    exit 0
fi

# Add MariaDB repository
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${MARIADB_VER}" --skip-maxscale 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Repository"

# Install MariaDB
apt update --allow-releaseinfo-change -y 2>> /tmp/enginescript_install_errors.log
sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server mariadb-client -y' 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Installation"

# Update
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh 2>> /tmp/enginescript_install_errors.log
apt upgrade -y 2>> /tmp/enginescript_install_errors.log

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "System Update and Cleanup"

# New MariaDB Secure Method
# Probably safer to do the secure installation manually, as the previous method would break if MariaDB changed anything in the order that they ask questions.

# Set password with `debconf-set-selections` You don't have to enter it in prompt
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MARIADB_ADMIN_PASSWORD}" # new password for the MySQL root user
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MARIADB_ADMIN_PASSWORD}" # repeat password for the MySQL root user

# Remote Connection to Database - use unix_socket for local root and ed25519 for password-based auth
sudo mariadb -e "ALTER USER root@localhost IDENTIFIED VIA unix_socket OR ed25519 USING PASSWORD('${MARIADB_ADMIN_PASSWORD}');"

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
cp -rf /usr/local/bin/enginescript/config/etc/mysql/my.cnf /etc/mysql/my.cnf

# Create Logs
touch /var/log/mysql/mysql-error.log
touch /var/log/mysql/mariadb-slow.log
touch /var/log/mysql/mysql.log
chown -R mysql:adm /var/log/mysql/mysql-error.log
chown -R mysql:adm /var/log/mysql/mariadb-slow.log
chown -R mysql:adm /var/log/mysql/mysql.log

# Tune MariaDB
/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MariaDB Configuration"

# Ensure MariaDB service always restarts on failure
if grep -q '^Restart=on-abnormal' /lib/systemd/system/mariadb.service; then
  sed -i 's/^Restart=on-abnormal/Restart=always/' /lib/systemd/system/mariadb.service
  systemctl daemon-reload
fi

# Restart Service
systemctl daemon-reload
systemctl start mariadb.service

# Check if services are running
verify_service_running "mariadb" "MariaDB"
verify_service_running "mysql" "MySQL"
mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'

print_install_banner "MariaDB" 2

# Mark the installation as complete
echo "MARIADB=1" >> /etc/enginescript/install-state.conf
