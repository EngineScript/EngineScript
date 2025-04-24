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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Start Normal Automatic Upgrade
sed -i "s/\$document_root\$fastcgi_script_name/\$realpath_root\$fastcgi_script_name/g; s/\(fastcgi_param[[:space:]]*DOCUMENT_ROOT[[:space:]]*\)\$document_root/\1$realpath_root/g" /etc/nginx/globals/fastcgi-modified.conf

# Fix Existing Redis Socket Permissions
sed -i 's/^unixsocketperm 777/unixsocketperm 770/' /etc/redis/redis.conf

# Ensure correct socket ownership and permissions
chown redis:redis /run/redis/redis-server.sock 2>/dev/null || true
chmod 770 /run/redis/redis-server.sock 2>/dev/null || true

# Add www-data to Redis Group
if ! getent group redis > /dev/null; then
  groupadd redis
fi
usermod -aG redis www-data

# Restart Services
sudo systemctl restart redis
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
