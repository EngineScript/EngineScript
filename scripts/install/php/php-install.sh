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

# Update & Upgrade
run_step "System Update" /usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

# Install PHP
# Define the PHP packages to install
mapfile -t php_packages < <(get_php_packages_array "${PHP_VER}")

# Install the packages with error checking
apt-get install -qy "${php_packages[@]}" 2>> "${ES_STEP_ERROR_LOG}" || {
  echo "Error: Unable to install one or more packages. Exiting..."
    exit 1
}
print_last_errors
debug_pause "PHP Package Installation"

# Logrotate
sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${PHP_VER}-fpm"

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh 2>> "${ES_STEP_ERROR_LOG}"

# Update PHP config
run_step "PHP Configuration" /usr/local/bin/enginescript/scripts/update/php-config-update.sh || die "The PHP configuration could not be applied. Stopping the PHP install; see /var/log/EngineScript/install-error-log.log."

mkdir -p /var/cache/opcache
mkdir -p /var/cache/php-sessions
mkdir -p /var/cache/wsdlcache

# Assign PHP Permissions
set_php_permissions

# Restart PHP
restart_service "php${PHP_VER}-fpm"

# PHP Service Check
verify_service_running "php${PHP_VER}-fpm" "PHP ${PHP_VER}"

print_install_banner "PHP ${PHP_VER}"

# Cleanup
run_step "Cleanup" run_enginescript_cleanup

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

echo "PHP completed successfully. Script done."
