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



#----------------------------------------------------------------------------------
# Start Main Script

# Retrieve EngineScript Nginx Configuration
cp -a /usr/local/bin/enginescript/config/etc/nginx/. /etc/nginx/
sed -i "s|SEDPHPVER|${PHP_VER}|g" /etc/nginx/globals/php-fpm.conf

# Assign Permissions
chown -R www-data:www-data /etc/nginx
chown -R www-data:www-data /tmp/nginx_proxy
chown -R www-data:www-data /usr/lib/nginx/modules
chown -R www-data:www-data /var/cache/nginx
chown -R www-data:www-data /var/lib/nginx
chown -R www-data:www-data /var/log/domains
chown -R www-data:www-data /var/log/nginx
chown -R www-data:www-data /var/www
chmod 775 /var/cache/nginx

# Logrotate - Nginx and Domains
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/nginx /etc/logrotate.d/nginx
cp -rf /usr/local/bin/enginescript/config/etc/logrotate.d/domains /etc/logrotate.d/domains
find /etc/logrotate.d -type f -print0 | sudo xargs -0 chmod 0644
