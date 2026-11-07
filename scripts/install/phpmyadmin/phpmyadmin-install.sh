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

source /etc/enginescript/install-state.conf
if [[ "${PHPMYADMIN}" = 1 ]]; then
    echo "PHPMYADMIN script has already run"
    exit 0
fi

if [[ "${INSTALL_PHPMYADMIN}" != "1" ]]; then
    echo "Skipping phpMyAdmin install"
    exit 0
fi

# phpMyAdmin

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# Download phpMyAdmin
download_file "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip"
unzip -q -o "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip" -d "/usr/src"
mv "/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages" "/var/www/admin/tools/phpmyadmin"
mkdir -p /var/www/admin/tools/phpmyadmin/tmp
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin

# phpMyAdmin Cookie Encryption
sed -e "s|cfg\['blowfish_secret'\] = ''|cfg\['blowfish_secret'\] = '$RAND_CHAR32'|" /var/www/admin/tools/phpmyadmin/config.sample.inc.php > /var/www/admin/tools/phpmyadmin/config.inc.php

# phpMyAdmin Control User (server)
sed -i "s|'pma'|'phpmyadmin_controlusr_$RAND_CHAR8'|g" /var/www/admin/tools/phpmyadmin/config.inc.php | mariadb -e "CREATE USER 'phpmyadmin_controlusr_${RAND_CHAR8}'@'localhost' IDENTIFIED BY '${RAND_CHAR24}';"
sed -i "s|'pmapass'|'$RAND_CHAR24'|g" /var/www/admin/tools/phpmyadmin/config.inc.php | mariadb -e "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'phpmyadmin_controlusr_${RAND_CHAR8}'@'localhost'; FLUSH PRIVILEGES;"

# Create phpMyAdmin Tables
mariadb < /var/www/admin/tools/phpmyadmin/sql/create_tables.sql

# User Login Credentials
mariadb -e "CREATE USER ${PHPMYADMIN_USERNAME}@'localhost' IDENTIFIED BY '${PHPMYADMIN_PASSWORD}';"
mariadb -e "GRANT ALL PRIVILEGES ON *.* TO ${PHPMYADMIN_USERNAME}@'localhost'; FLUSH PRIVILEGES;"

# Post-Install Cleanup
run_enginescript_cleanup

print_install_banner "phpMyAdmin"

set_install_state "PHPMYADMIN" "1"
