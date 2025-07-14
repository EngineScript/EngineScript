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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing? This will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi

echo ""
echo "============================================================="
echo ""
echo "PHP Upgrade: Migrating from PHP 8.3 to PHP ${PHP_VER}"
echo ""
echo "============================================================="
echo ""

# Define old and new PHP versions
OLD_PHP_VER="8.3"
NEW_PHP_VER="${PHP_VER}"

# Verify we're upgrading to 8.4
if [[ "${NEW_PHP_VER}" != "8.4" ]]; then
    echo "Error: This script is designed to upgrade to PHP 8.4 only."
    echo "Current PHP_VER variable is set to: ${NEW_PHP_VER}"
    exit 1
fi

# Check if PHP 8.3 is currently installed
if ! dpkg -l | grep -q "php${OLD_PHP_VER}-fpm"; then
    echo "PHP ${OLD_PHP_VER} is not installed. Nothing to upgrade."
    exit 0
fi

echo "Detected PHP ${OLD_PHP_VER} installation. Proceeding with upgrade..."

# Stop PHP 8.3 service
echo "Stopping PHP ${OLD_PHP_VER} service..."
systemctl stop "php${OLD_PHP_VER}-fpm" 2>/dev/null || true

# Install PHP 8.4
echo "Installing PHP ${NEW_PHP_VER}..."

# Define the PHP packages to install
php_packages="php${NEW_PHP_VER}
php${NEW_PHP_VER}-bcmath
php${NEW_PHP_VER}-common
php${NEW_PHP_VER}-curl
php${NEW_PHP_VER}-fpm
php${NEW_PHP_VER}-gd
php${NEW_PHP_VER}-imagick
php${NEW_PHP_VER}-intl
php${NEW_PHP_VER}-mbstring
php${NEW_PHP_VER}-mysql
php${NEW_PHP_VER}-opcache
php${NEW_PHP_VER}-redis
php${NEW_PHP_VER}-ssh2
php${NEW_PHP_VER}-xml
php${NEW_PHP_VER}-zip"

# Install the packages with error checking
apt install -qy $php_packages || {
    echo "Error: Unable to install PHP ${NEW_PHP_VER} packages. Exiting..."
    exit 1
}

# Install expanded PHP packages if enabled
if [[ "$INSTALL_EXPANDED_PHP" == "1" ]]; then
    echo "Installing expanded PHP ${NEW_PHP_VER} packages..."
    expanded_php_packages="php${NEW_PHP_VER}-soap
php${NEW_PHP_VER}-sqlite3"

    apt install -qy $expanded_php_packages || {
        echo "Error: Unable to install expanded PHP ${NEW_PHP_VER} packages. Exiting..."
        exit 1
    }
fi

# Copy PHP 8.3 configuration to PHP 8.4
echo "Migrating PHP configuration from ${OLD_PHP_VER} to ${NEW_PHP_VER}..."

# Copy php.ini
if [[ -f "/etc/php/${OLD_PHP_VER}/fpm/php.ini" ]]; then
    cp "/etc/php/${OLD_PHP_VER}/fpm/php.ini" "/etc/php/${NEW_PHP_VER}/fpm/php.ini"
fi

# Copy pool configuration
if [[ -f "/etc/php/${OLD_PHP_VER}/fpm/pool.d/www.conf" ]]; then
    cp "/etc/php/${OLD_PHP_VER}/fpm/pool.d/www.conf" "/etc/php/${NEW_PHP_VER}/fpm/pool.d/www.conf"
fi

# Copy php-fpm.conf
if [[ -f "/etc/php/${OLD_PHP_VER}/fpm/php-fpm.conf" ]]; then
    cp "/etc/php/${OLD_PHP_VER}/fpm/php-fpm.conf" "/etc/php/${NEW_PHP_VER}/fpm/php-fpm.conf"
fi

# Update configuration references from 8.3 to 8.4
echo "Updating configuration references..."

# Update logrotate configuration
if [[ -f "/etc/logrotate.d/php${OLD_PHP_VER}-fpm" ]]; then
    sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${NEW_PHP_VER}-fpm"
fi

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh

# Update PHP config with the latest EngineScript settings
/usr/local/bin/enginescript/scripts/update/php-config-update.sh

# Create necessary directories and log files
mkdir -p /var/cache/opcache
mkdir -p /var/cache/php-sessions
mkdir -p /var/cache/wsdlcache
mkdir -p /var/log/opcache
mkdir -p /var/log/php

touch "/var/log/opcache/opcache.log"
touch "/var/log/php/php${NEW_PHP_VER}-fpm.log"

# Set permissions
find "/var/log/php" -type d,f -exec chmod 775 {} \;
find "/var/log/opcache" -type d,f -exec chmod 775 {} \;
find "/etc/php" -type d,f -exec chmod 775 {} \;
chmod 775 /var/cache/opcache
chmod 775 /var/cache/php-sessions
chmod 775 /var/cache/wsdlcache
chown -R www-data:www-data /var/cache/opcache
chown -R www-data:www-data /var/cache/php-sessions
chown -R www-data:www-data /var/cache/wsdlcache
chown -R www-data:www-data /var/log/opcache
chown -R www-data:www-data /var/log/php
chown -R www-data:www-data /etc/php

# Update Nginx configuration to use new PHP version
echo "Updating Nginx configuration for PHP ${NEW_PHP_VER}..."

# Update php-fpm.conf
if [[ -f "/etc/nginx/globals/php-fpm.conf" ]]; then
    sed -i "s|php${OLD_PHP_VER}-fpm|php${NEW_PHP_VER}-fpm|g" "/etc/nginx/globals/php-fpm.conf"
    sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "/etc/nginx/globals/php-fpm.conf"
fi

# Update all nginx site configurations
for config_file in /etc/nginx/sites-available/*; do
    if [[ -f "$config_file" ]]; then
        sed -i "s|php${OLD_PHP_VER}-fpm|php${NEW_PHP_VER}-fpm|g" "$config_file"
        sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "$config_file"
    fi
done

# Update phpinfo configuration
echo "Updating phpinfo configuration..."
if [[ -f "/var/www/admin/enginescript/phpinfo/phpsysinfo.ini" ]]; then
    sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "/var/www/admin/enginescript/phpinfo/phpsysinfo.ini"
fi

# Update API configuration to be dynamic for both PHP versions
echo "Updating admin control panel API configuration..."
if [[ -f "/var/www/admin/enginescript/api.php" ]]; then
    # Make PHP service detection dynamic
    sed -i "s/'php8\.3-fpm'/'php8.4-fpm', 'php8.3-fpm'/g" "/var/www/admin/enginescript/api.php"
    sed -i "s/getServiceStatus('php8\.3-fpm')/getServiceStatus('php8.4-fpm') ?: getServiceStatus('php8.3-fpm')/g" "/var/www/admin/enginescript/api.php"
    sed -i "s/case 'php8\.3-fpm':/case 'php8.4-fpm':\n        case 'php8.3-fpm':/g" "/var/www/admin/enginescript/api.php"
fi

# Update debug script
if [[ -f "/usr/local/bin/enginescript/scripts/functions/alias/alias-debug.sh" ]]; then
    sed -i "s/php8\.3-fpm/php8.4-fpm/g" "/usr/local/bin/enginescript/scripts/functions/alias/alias-debug.sh"
fi

# Start PHP 8.4 service
echo "Starting PHP ${NEW_PHP_VER} service..."
systemctl enable "php${NEW_PHP_VER}-fpm"
systemctl start "php${NEW_PHP_VER}-fpm"

# Reload Nginx to pick up the new PHP configuration
echo "Reloading Nginx configuration..."
systemctl reload nginx

# PHP Service Check
STATUS="$(systemctl is-active "php${NEW_PHP_VER}-fpm")"
if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: PHP ${NEW_PHP_VER} is running."
    echo "PHP=1" >> /var/log/EngineScript/install-log.txt
else
    echo "FAILED: PHP ${NEW_PHP_VER} not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Remove PHP 8.3 if not keeping it
if [[ "${INSTALL_PHP83}" != "1" ]]; then
    echo "Removing PHP ${OLD_PHP_VER} installation..."
    
    # Stop and disable PHP 8.3 service
    systemctl stop "php${OLD_PHP_VER}-fpm" 2>/dev/null || true
    systemctl disable "php${OLD_PHP_VER}-fpm" 2>/dev/null || true
    
    # Remove PHP 8.3 packages
    apt purge -y php${OLD_PHP_VER}* 2>/dev/null || true
    
    # Remove PHP 8.3 configuration directory
    rm -rf "/etc/php/${OLD_PHP_VER}" 2>/dev/null || true
    
    # Remove PHP 8.3 logrotate configuration
    rm -f "/etc/logrotate.d/php${OLD_PHP_VER}-fpm" 2>/dev/null || true
    
    # Clean up old logs (keep for reference but rename)
    if [[ -f "/var/log/php/php${OLD_PHP_VER}-fpm.log" ]]; then
        mv "/var/log/php/php${OLD_PHP_VER}-fpm.log" "/var/log/php/php${OLD_PHP_VER}-fpm.log.old" 2>/dev/null || true
    fi
    
    echo "PHP ${OLD_PHP_VER} has been removed."
else
    echo "PHP ${OLD_PHP_VER} has been kept alongside PHP ${NEW_PHP_VER}."
    echo "Note: Only PHP ${NEW_PHP_VER} is configured for use with Nginx."
fi

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# Display PHP version and modules
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php -version
echo ""
php -m

# Final message
echo ""
echo ""
echo "============================================================="
echo ""
echo "PHP upgrade from ${OLD_PHP_VER} to ${NEW_PHP_VER} completed successfully."
echo ""
echo "Changes made:"
echo "  - Installed PHP ${NEW_PHP_VER} and extensions"
echo "  - Migrated configuration from PHP ${OLD_PHP_VER}"
echo "  - Updated Nginx configuration"
echo "  - Updated admin control panel API"
echo "  - Updated debug scripts"
if [[ "${INSTALL_PHP83}" != "1" ]]; then
    echo "  - Removed PHP ${OLD_PHP_VER} installation"
fi
echo ""
echo "============================================================="
echo ""
