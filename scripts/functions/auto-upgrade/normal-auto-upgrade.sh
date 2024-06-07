#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Update default.conf
cp -a /usr/local/bin/enginescript/etc/nginx/globals/default.conf /etc/nginx/globals/default.conf

# Update wpsecure.conf
cp -a /usr/local/bin/enginescript/etc/nginx/globals/wpsecure.conf /etc/nginx/globals/wpsecure.conf

# Remove fastcgi_params
sed -i "s|include fastcgi_params;||g" /etc/nginx/globals/*.conf
sed -i "s|include fastcgi_params;||g" /etc/nginx/sites-available/yourdomain.com.conf
sed -i "s|include fastcgi_params;||g" /etc/nginx/sites-enabled/*.conf

# Change index.php$is_args$args;
sed -i "s|index.php$is_args$args;|/index.php?$args;|g" /etc/nginx/globals/fcgicachelocation.conf

# Change server_names_hash_max_size
sed -i "s|server_names_hash_max_size 2048;|server_names_hash_max_size 512;|g" /etc/nginx/nginx.conf

# Change server_names_hash_max_size
sed -i "s|fastcgi_cache_valid 200 1h|fastcgi_cache_valid 200 2h|g" /etc/nginx/nginx.conf

# Change server_names_hash_max_size
sed -i "s|\"; expires -1 always;|\" always; expires -1;|g" /etc/nginx/globals/staticfiles.conf

# Remove http to https redirect
# This was moved to default.conf and converted into a universal redirect for all domains
sed -i '/# Forward HTTP Traffic to HTTPS/,/^$/d' /etc/nginx/sites-available/yourdomain.com.conf
sed -i '/# Forward HTTP Traffic to HTTPS/,/^$/d' /etc/nginx/sites-enabled/*.conf

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
