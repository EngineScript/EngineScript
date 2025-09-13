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

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

#----------------------------------------------------------------------------------
# Start Main Script

# Upgrade Scripts will be found below:

# Update Nginx configuration files with security and performance improvements (September 2025)
echo "Updating Nginx configuration files with latest security enhancements..."

# Fix nginx.conf redirect caching - replace separate 301/302 lines with combined line
if [[ -f "/etc/nginx/nginx.conf" ]]; then
    sed -i '/fastcgi_cache_valid 301 1d;/c\  fastcgi_cache_valid 301 302 0;' /etc/nginx/nginx.conf
    sed -i '/fastcgi_cache_valid 302 1h;/d' /etc/nginx/nginx.conf
    echo "✓ Updated nginx.conf (redirect loop prevention)"
fi

# FastCGI modified config - WordPress HTTPS detection for Cloudflare
if [[ -f "/etc/nginx/globals/fastcgi-modified.conf" ]]; then
    cp "/usr/local/bin/enginescript/config/etc/nginx/globals/fastcgi-modified.conf" "/etc/nginx/globals/fastcgi-modified.conf"
    echo "✓ Updated fastcgi-modified.conf (WordPress HTTPS detection)"
fi

# PHP-FPM config - WooCommerce session bleeding prevention
if [[ -f "/etc/nginx/globals/php-fpm.conf" ]]; then
    cp "/usr/local/bin/enginescript/config/etc/nginx/globals/php-fpm.conf" "/etc/nginx/globals/php-fpm.conf"
    sed -i "s|SEDPHPVER|${PHP_VER}|g" /etc/nginx/globals/php-fpm.conf
    echo "✓ Updated php-fpm.conf (WooCommerce session security)"
fi

# Map cache config - X-Cache-Enabled logic optimization
if [[ -f "/etc/nginx/globals/map-cache.conf" ]]; then
    cp "/usr/local/bin/enginescript/config/etc/nginx/globals/map-cache.conf" "/etc/nginx/globals/map-cache.conf"
    echo "✓ Updated map-cache.conf (performance optimization)"
fi

# Response headers config - X-Cache-Enabled header cleanup
if [[ -f "/etc/nginx/globals/response-headers.conf" ]]; then
    cp "/usr/local/bin/enginescript/config/etc/nginx/globals/response-headers.conf" "/etc/nginx/globals/response-headers.conf"
    echo "✓ Updated response-headers.conf (header optimization)"
fi

# Remove deprecated SSL defines from wp-config.php files
if [[ -f "/home/EngineScript/sites-list/sites.sh" ]]; then
    source /home/EngineScript/sites-list/sites.sh
    echo "Removing deprecated SSL defines from wp-config.php files..."
    
    for site in "${SITES[@]}"
    do
        wp_config_file="/var/www/sites/$site/html/wp-config.php"
        if [[ -f "$wp_config_file" ]]; then
            # Remove the SSL comment and defines (lines that were removed from template)
            sed -i '/\/\* SSL \*\//d' "$wp_config_file"
            sed -i "/define( 'FORCE_SSL_ADMIN', true );/d" "$wp_config_file"
            sed -i "/define( 'FORCE_SSL_LOGIN', true );/d" "$wp_config_file"
            echo "✓ Updated wp-config.php for site: $site"
        fi
    done
else
    echo "Sites list not found - skipping wp-config.php updates"
fi

# Test nginx configuration and reload if valid
if nginx -t > /dev/null 2>&1; then
    systemctl reload nginx
    echo "✓ Nginx configuration updated and reloaded successfully"
else
    echo "✗ Nginx configuration test failed - please check nginx logs"
fi

# Remove EngineScript logrotate configuration to preserve install logs (September 2025)
if [[ -f "/etc/logrotate.d/enginescript" ]]; then
    rm -f "/etc/logrotate.d/enginescript"
    echo "✓ Removed EngineScript logrotate configuration (preserves install logs)"
fi

# Update Cloudflare IP ranges to ensure complete coverage (September 2025)
if [[ -f "/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare-ip-updater.sh" ]]; then
    echo "Updating Cloudflare IP ranges..."
    bash /usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare-ip-updater.sh
    echo "✓ Updated Cloudflare IP ranges (complete coverage including latest ranges)"
fi

