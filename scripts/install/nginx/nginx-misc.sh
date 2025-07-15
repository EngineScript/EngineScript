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

# Create nginx user and group if they don't exist
if ! id "www-data" &>/dev/null; then
    useradd -r -s /bin/false www-data
fi

# Ensure all necessary directories exist
mkdir -p /var/log/nginx
mkdir -p /var/log/domains
mkdir -p /var/cache/nginx
mkdir -p /var/lib/nginx/{body,fastcgi,proxy}
mkdir -p /tmp/nginx_proxy
mkdir -p /usr/lib/nginx/modules

# Assign Permissions BEFORE nginx tries to start
set_nginx_permissions

# Logrotate - Nginx and Domains
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/nginx /etc/logrotate.d/nginx
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/domains /etc/logrotate.d/domains
find /etc/logrotate.d -type f -print0 | sudo xargs -0 chmod 0644
