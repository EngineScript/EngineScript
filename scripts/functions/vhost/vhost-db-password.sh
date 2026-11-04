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

# Source shared database credential functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# Give a site's database user a new random password, and put it in the site's wp-config.php and
# in /home/EngineScript/mysql-credentials/<domain>.txt. If any step fails, the old password goes
# back in MariaDB and wp-config.php is restored, so the site keeps working.
#
# Usage: vhost-db-password.sh <domain>

DOMAIN="${1:-}"
CREDENTIALS="/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
SITE_ROOT="/var/www/sites/${DOMAIN}/html"
WP_CONFIG="${SITE_ROOT}/wp-config.php"
# Kept outside the site folder: a copy of wp-config.php there could be downloaded
WP_CONFIG_BACKUP="/home/EngineScript/mysql-credentials/${DOMAIN}-wp-config.php.bak"
CREDENTIALS_BACKUP="/home/EngineScript/mysql-credentials/${DOMAIN}-credentials.bak"

# One value from the credentials file (KEY="value" lines), read without sourcing it
read_credential() {
  sed -n "s/^$1=\"\(.*\)\"$/\1/p" "${CREDENTIALS}" 2> /dev/null | head -n 1
}

# Set the database user's password in MariaDB
set_mariadb_password() {
  mariadb -e "ALTER USER '${USR}'@'localhost' IDENTIFIED BY '$(escape_sql_string_literal "$1")';"
}

# True when both MariaDB and WordPress (through wp-config.php) accept the password
password_works() {
  MYSQL_PWD="$1" mariadb -u "${USR}" -N -B -e "SELECT 1" "${DB}" > /dev/null 2>&1 \
    && (cd "${SITE_ROOT}" && run_as_www_data wp db query "SELECT 1" --skip-plugins --skip-themes > /dev/null 2>&1)
}

roll_back() {
  echo "Error: $1 Putting the old password back..." >&2
  cp -p "${WP_CONFIG_BACKUP}" "${WP_CONFIG}"
  cp -p "${CREDENTIALS_BACKUP}" "${CREDENTIALS}"
  if set_mariadb_password "${PSWD}" && password_works "${PSWD}"; then
    echo "The old password is back in place; ${DOMAIN} works as before." >&2
    rm -f "${WP_CONFIG_BACKUP}" "${CREDENTIALS_BACKUP}"
  else
    echo "Error: The old password could not be restored. The old wp-config.php and credentials are in" >&2
    echo "${WP_CONFIG_BACKUP} and ${CREDENTIALS_BACKUP}." >&2
  fi
  exit 1
}

if [[ -z "${DOMAIN}" ]] || ! grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh 2> /dev/null; then
  echo "Usage: $0 <domain>, where <domain> is in /home/EngineScript/sites-list/sites.sh" >&2
  exit 2
fi
if [[ ! -f "${WP_CONFIG}" ]]; then
  echo "Error: ${DOMAIN} has no WordPress (${WP_CONFIG})." >&2
  exit 1
fi
DB="$(read_credential DB)"
USR="$(read_credential USR)"
PSWD="$(read_credential PSWD)"
if ! validate_db_identifier "${DB}" "${DOMAIN}" || [[ ! "${USR}" =~ ^[A-Za-z0-9_]+$ || -z "${PSWD}" ]]; then
  echo "Error: Could not read the database credentials in ${CREDENTIALS}." >&2
  exit 1
fi
if ! password_works "${PSWD}"; then
  echo "Error: The current password in ${CREDENTIALS} does not work for ${DOMAIN}, so nothing was changed." >&2
  echo "Check that it matches DB_PASSWORD in ${WP_CONFIG}." >&2
  exit 1
fi

NEW_PASSWORD="${RAND_CHAR32}"
validate_install_credentials "${USR}" "${NEW_PASSWORD}" "${DOMAIN}" || exit 1

if ! cp -p "${WP_CONFIG}" "${WP_CONFIG_BACKUP}" || ! cp -p "${CREDENTIALS}" "${CREDENTIALS_BACKUP}"; then
  rm -f "${WP_CONFIG_BACKUP}" "${CREDENTIALS_BACKUP}"
  echo "Error: Could not back up ${WP_CONFIG} and ${CREDENTIALS}, so nothing was changed." >&2
  exit 1
fi
chmod 600 "${WP_CONFIG_BACKUP}" "${CREDENTIALS_BACKUP}"

echo "Setting a new password for ${DOMAIN}'s database user..."
set_mariadb_password "${NEW_PASSWORD}" || roll_back "MariaDB did not take the new password."
(cd "${SITE_ROOT}" && run_as_www_data wp config set DB_PASSWORD "${NEW_PASSWORD}" --type=constant --quiet) \
  || roll_back "The new password could not be written to wp-config.php."
password_works "${NEW_PASSWORD}" || roll_back "The site cannot connect with the new password."
sed -i "s/^PSWD=\".*\"$/PSWD=\"${NEW_PASSWORD}\"/" "${CREDENTIALS}"
[[ "$(read_credential PSWD)" == "${NEW_PASSWORD}" ]] || roll_back "The new password could not be saved in ${CREDENTIALS}."

rm -f "${WP_CONFIG_BACKUP}" "${CREDENTIALS_BACKUP}"
echo "Done! ${DOMAIN} now uses a new database password, saved in ${CREDENTIALS}."
