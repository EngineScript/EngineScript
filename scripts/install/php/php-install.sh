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

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "System Update"

# Install PHP
# Define the PHP packages to install
php_packages="php${PHP_VER}
php${PHP_VER}-bcmath
php${PHP_VER}-common
php${PHP_VER}-curl
php${PHP_VER}-fpm
php${PHP_VER}-gd
php${PHP_VER}-imagick
php${PHP_VER}-intl
php${PHP_VER}-mbstring
php${PHP_VER}-mysql
php${PHP_VER}-redis
php${PHP_VER}-ssh2
php${PHP_VER}-xml
php${PHP_VER}-zip"

# PHP 8.5+ has opcache built-in; older versions need the separate package
# Convert PHP_VER (e.g. "8.4") into an integer (e.g. 84) for numeric comparison
php_major=${PHP_VER%%.*}
php_minor=${PHP_VER#*.}
php_ver_int=$((php_major * 10 + php_minor))
if (( php_ver_int < 85 )); then
    php_packages="${php_packages}
php${PHP_VER}-opcache"
fi

# Install the packages with error checking
# Unquoted expansion relies on word splitting (spaces and newlines)
apt install -qy $php_packages 2>> /tmp/enginescript_install_errors.log || {
  echo "Error: Unable to install one or more packages. Exiting..."
    exit 1
}

if [[ "$INSTALL_EXPANDED_PHP" == "1" ]];
    then
    expanded_php_packages="php${PHP_VER}-soap
php${PHP_VER}-sqlite3"

    # Install the packages with error checking
    # Unquoted expansion relies on word splitting (spaces and newlines)
    apt install -qy $expanded_php_packages 2>> /tmp/enginescript_install_errors.log || {
      echo "Error: Unable to install one or more packages. Exiting..."
      exit 1
    }
fi
print_last_errors
debug_pause "PHP Package Installation"

# Logrotate
cp -rf "/usr/local/bin/enginescript/config/etc/logrotate.d/opcache" "/etc/logrotate.d/opcache"
sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${PHP_VER}-fpm"

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh 2>> /tmp/enginescript_install_errors.log

# Update PHP config
/usr/local/bin/enginescript/scripts/update/php-config-update.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "PHP Configuration"

mkdir -p /var/cache/opcache
mkdir -p /var/cache/php-sessions
mkdir -p /var/cache/wsdlcache
mkdir -p /var/log/opcache
mkdir -p /var/log/php

touch "/var/log/opcache/opcache.log"
touch "/var/log/php/php${PHP_VER}-fpm.log"
#touch /var/log/php/php.log
#touch /var/log/php/php-www.log
#touch /var/log/php/php-fpm.log

# Assign PHP Permissions
set_php_permissions

# Restart PHP
restart_service "php${PHP_VER}-fpm"

# PHP Service Check
verify_service_running "php${PHP_VER}-fpm" "PHP" "PHP ${PHP_VER}"

print_install_banner "PHP ${PHP_VER}"

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh 2>> /tmp/enginescript_install_errors.log
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cleanup"

# References:
# https://make.wordpress.org/hosting/handbook/server-environment/#php-extensions
# https://hub.dakidarts.com/php-fpm-process-managers-ondemand-vs-dynamic-vs-static/
# https://rhuaridh.co.uk/blog/php-fpm-performance-tuning.html
# https://chrismoore.ca/2018/10/finding-the-correct-pm-max-children-settings-for-php-fpm/
# https://tideways.com/tools/fpm-configuration-calculator
# https://community.webcore.cloud/tutorials/php_fpm_ondemand_process_manager_vs_dynamic/
# https://php-fpm.gkanev.com/
# https://spot13.com/pmcalculator/
# https://linuxblog.io/php-fpm-tuning-using-pm-static-max-performance/
# https://github.com/littlebizzy/slickstack
# https://flywp.com/blog/9281/optimize-php-fpm-settings-flywp/
# https://www.managedserver.eu/introduction-to-php-fpm-tuning/