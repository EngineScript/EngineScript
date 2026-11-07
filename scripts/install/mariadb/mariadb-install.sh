#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

escape_mariadb_sql_string_literal() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\'/\'\'}"
  printf '%s' "$input"
}

# Add MariaDB repository. The setup script is saved before it runs, so a download that breaks off
# cannot run part of it, and a failed download stops here instead of installing Ubuntu's MariaDB.
REPO_SETUP="$(mktemp)"
if ! curl -fLsS --proto '=https' -o "${REPO_SETUP}" https://downloads.mariadb.com/MariaDB/mariadb_repo_setup 2>> "${ES_STEP_ERROR_LOG}"; then
  rm -f "${REPO_SETUP}"
  print_last_errors
  echo "Error: Could not download MariaDB's repository setup script. MariaDB was not installed." >&2
  exit 1
fi
if ! bash "${REPO_SETUP}" --mariadb-server-version="${MARIADB_VER}" --skip-maxscale 2>> "${ES_STEP_ERROR_LOG}"; then
  rm -f "${REPO_SETUP}"
  print_last_errors
  echo "Error: MariaDB's repository setup failed. MariaDB was not installed." >&2
  exit 1
fi
rm -f "${REPO_SETUP}"
print_last_errors
debug_pause "MariaDB Repository"

# Install MariaDB
apt-get update --allow-releaseinfo-change -y 2>> "${ES_STEP_ERROR_LOG}"
if ! DEBIAN_FRONTEND=noninteractive apt-get install -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold mariadb-server mariadb-client -y 2>> "${ES_STEP_ERROR_LOG}"; then
  print_last_errors
  echo "Error: The MariaDB packages could not be installed. Stopping the MariaDB install; see /var/log/EngineScript/install-error-log.log." >&2
  exit 1
fi
print_last_errors
debug_pause "MariaDB Installation"

# Update
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh 2>> "${ES_STEP_ERROR_LOG}"
apt-get upgrade -y 2>> "${ES_STEP_ERROR_LOG}"

# Cleanup
run_step "System Update and Cleanup" run_enginescript_cleanup

# New MariaDB Secure Method
# Probably safer to do the secure installation manually, as the previous method would break if MariaDB changed anything in the order that they ask questions.

# The root password and secure-installation SQL below need a running MariaDB. apt normally
# starts it after the install; start it if not, and stop the install if it does not answer,
# instead of continuing without a root password.
if ! systemctl is-active --quiet mariadb; then
  systemctl start mariadb 2>> "${ES_STEP_ERROR_LOG}"
fi
MARIADB_READY=0
for _ in $(seq 1 15); do
  if mariadb --protocol=socket -e "SELECT 1" > /dev/null 2>&1; then
    MARIADB_READY=1
    break
  fi
  sleep 2
done
if [[ "${MARIADB_READY}" != "1" ]]; then
  echo "Error: MariaDB is not running, so the root password and secure-installation steps cannot run. Check 'systemctl status mariadb' and /var/log/mysql/." >&2
  exit 1
fi

# Keep local sudo/socket automation working while enabling the configured root password.
SQL_ESCAPED_MARIADB_ADMIN_PASSWORD="$(escape_mariadb_sql_string_literal "${MARIADB_ADMIN_PASSWORD}")"
if ! mariadb --protocol=socket << EOFMYSQLROOTAUTH
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('${SQL_ESCAPED_MARIADB_ADMIN_PASSWORD}');
EOFMYSQLROOTAUTH
then
  echo "Error: Setting the MariaDB root password failed." >&2
  exit 1
fi

# Manually Perform Secure Installation
if ! mariadb --protocol=socket << EOFMYSQLSECURE
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOFMYSQLSECURE
then
  echo "Error: The MariaDB secure-installation step failed." >&2
  exit 1
fi

# Copy MariaDB Config
systemctl stop mariadb.service
cp -rf /usr/local/bin/enginescript/config/etc/mysql/my.cnf /etc/mysql/my.cnf

# Directory for secure_file_priv (my.cnf); MariaDB does not start without it
install -d -o mysql -g mysql -m 750 /var/lib/mysql-files

# Create Logs
touch /var/log/mysql/mysql-error.log
touch /var/log/mysql/mariadb-slow.log
touch /var/log/mysql/mysql.log
chown -R mysql:adm /var/log/mysql/mysql-error.log
chown -R mysql:adm /var/log/mysql/mariadb-slow.log
chown -R mysql:adm /var/log/mysql/mysql.log

# Tune MariaDB
run_step "MariaDB Configuration" /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh

# Restart=always comes from EngineScript's systemd override (mariadb-tune.sh), which package
# upgrades leave alone, unlike the package's own /lib/systemd/system/mariadb.service

# Restart Service
systemctl daemon-reload
systemctl start mariadb.service

# Check if services are running
verify_service_running "mariadb" "MariaDB"
verify_service_running "mysql" "MySQL"
mariadbd --verbose --help 2>/dev/null | sed -n '/^Variables (--variable-name=value)/,$p'

print_install_banner "MariaDB" 2

echo "MariaDB completed successfully. Script done."
