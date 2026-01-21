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

#Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Retrieve EngineScript Nginx Configuration
cp -a /usr/local/bin/enginescript/config/etc/nginx/. /etc/nginx/
sed -i "s|SEDPHPVER|${PHP_VER}|g" /etc/nginx/globals/php-fpm.conf

# Disable TLS 1.1 if high security SSL is enabled
if [[ "${HIGH_SECURITY_SSL}" == "1" ]]; then
    sed -i 's|ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;|ssl_protocols TLSv1.2 TLSv1.3;|g' /etc/nginx/ssl/sslshared.conf
fi

# Enable unsafe file blocking if configured
if [[ "${NGINX_BLOCK_UNSAFE_FILES}" == "1" ]]; then
    sed -i 's|^  #\("~\*\\.\(?:asc\|  \1|' /etc/nginx/globals/map-cache.conf
    sed -i 's|^  #\("~\*(Gemfile\|  \1|' /etc/nginx/globals/map-cache.conf
    sed -i 's|^  #\("~\*(changelog\|  \1|' /etc/nginx/globals/map-cache.conf
    sed -i 's|^  #\("~\*gems\\.\|  \1|' /etc/nginx/globals/map-cache.conf
    sed -i 's|^  #\("~\*/wp-content/updraft/\|  \1|' /etc/nginx/globals/map-cache.conf
    sed -i 's|^  #\("~\*/wp-content/uploads/\.\*\\.\|  \1|' /etc/nginx/globals/map-cache.conf
fi

# Create nginx user and group if they don't exist
if ! id "www-data" &>/dev/null; then
    useradd -r -s /bin/false www-data
fi

# Assign Permissions BEFORE nginx tries to start
set_nginx_permissions

# Logrotate - Nginx and Domains
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/nginx /etc/logrotate.d/nginx
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/domains /etc/logrotate.d/domains
find /etc/logrotate.d -type f -print0 | sudo xargs -0 chmod 0644
