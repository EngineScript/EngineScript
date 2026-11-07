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

if [[ "${INSTALL_PHPMYADMIN}" != "1" ]]; then
    echo "Skipping phpMyAdmin install"
    exit 0
fi

# phpMyAdmin

# Download and unpack phpMyAdmin beside any copy already there, then swap it in
install_beside /var/www/admin/tools/phpmyadmin "phpMyAdmin" build_phpmyadmin || exit 1
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin

# Random values: the cookie encryption secret, and the control user's name and password
BLOWFISH_SECRET="$(es_random 32)"
CONTROL_USER_SUFFIX="$(es_random 8)"
CONTROL_USER_PASSWORD="$(es_random 24)"

# phpMyAdmin Cookie Encryption
sed -e "s|cfg\['blowfish_secret'\] = ''|cfg\['blowfish_secret'\] = '${BLOWFISH_SECRET}'|" /var/www/admin/tools/phpmyadmin/config.sample.inc.php > /var/www/admin/tools/phpmyadmin/config.inc.php

# phpMyAdmin Control User (server)
sed -i "s|'pma'|'phpmyadmin_controlusr_${CONTROL_USER_SUFFIX}'|g" /var/www/admin/tools/phpmyadmin/config.inc.php | mariadb -e "CREATE USER 'phpmyadmin_controlusr_${CONTROL_USER_SUFFIX}'@'localhost' IDENTIFIED BY '${CONTROL_USER_PASSWORD}';"
sed -i "s|'pmapass'|'${CONTROL_USER_PASSWORD}'|g" /var/www/admin/tools/phpmyadmin/config.inc.php | mariadb -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin_controlusr_${CONTROL_USER_SUFFIX}'@'localhost'; FLUSH PRIVILEGES;"

# Create phpMyAdmin Tables
mariadb < /var/www/admin/tools/phpmyadmin/sql/create_tables.sql

# User Login Credentials
mariadb -e "CREATE USER ${PHPMYADMIN_USERNAME}@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
mariadb -e "GRANT ALL PRIVILEGES ON *.* TO ${PHPMYADMIN_USERNAME}@'localhost'; FLUSH PRIVILEGES;"

# Post-Install Cleanup
run_enginescript_cleanup

print_install_banner "phpMyAdmin"
