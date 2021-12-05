#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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

# Install Redis
apt install redis-server redis-tools --no-install-recommends

# Setup Redis
mkdir -p /run/redis
mkdir -p /var/log/redis
touch /var/log/redis/redis.log
find /var/log/redis -type d,f -exec chmod 755 {} \;
chmod 775 /etc/redis/redis.conf
chmod 775 /run/redis
chown -R redis:redis /run/redis
chown -R redis:redis /var/log/redis

cp -rf /usr/local/bin/enginescript/etc/redis/redis.conf /etc/redis/redis.conf
sed -i "s|SEDREDISMAXMEM|${SERVER_MEMORY_TOTAL_07}|g" /etc/redis/redis.conf
chown -R redis:redis /etc/redis/redis.conf
service redis-server restart
sudo systemctl enable redis-server
