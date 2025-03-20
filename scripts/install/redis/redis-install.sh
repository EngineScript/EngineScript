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

# Install Redis
apt install -qy redis redis-server redis-tools

# Setup Redis
#mkdir -p /run/redis
#mkdir -p /var/lib/redis
#mkdir -p /var/log/redis
touch /var/log/redis/redis-server.log
find /var/lib/redis -type d,f -exec chmod 775 {} \;
find /var/lib/redis -type d,f -exec chmod 775 {} \;
chmod 775 /run/redis
chmod 775 /var/lib/redis
chmod 775 /var/log/redis
#chown -R redis:redis /run/redis
#chown -R redis:redis /var/lib/redis
#chown -R redis:redis /var/log/redis

# Copy Redis Config File
cp -rf /usr/local/bin/enginescript/config/etc/redis/redis.conf /etc/redis/redis.conf

# Redis Tuning
sed -i "s|SEDREDISMAXMEM|${SERVER_MEMORY_TOTAL_06}|g" /etc/redis/redis.conf

if [[ "${CPU_COUNT}" -ge '16' ]]; then
  sed -i "s|^# io-threads 4|io-threads 8|" /etc/redis/redis.conf
  sed -i "s|^# io-threads-do-reads no|io-threads-do-reads yes|" /etc/redis/redis.conf
  elif [[ "${CPU_COUNT}" -ge '12' && "${CPU_COUNT}" -le '15' ]]; then
    sed -i "s|^# io-threads 4|io-threads 6|" /etc/redis/redis.conf
    sed -i "s|^# io-threads-do-reads no|io-threads-do-reads yes|" /etc/redis/redis.conf
  elif [[ "${CPU_COUNT}" -ge '7' && "${CPU_COUNT}" -le '11' ]]; then
    sed -i "s|^# io-threads 4|io-threads 4|" /etc/redis/redis.conf
    sed -i "s|^# io-threads-do-reads no|io-threads-do-reads yes|" /etc/redis/redis.conf
  elif [[ "${CPU_COUNT}" -ge '4' && "${CPU_COUNT}" -le '6' ]]; then
    sed -i "s|^# io-threads 4|io-threads 2|" /etc/redis/redis.conf
    sed -i "s|^# io-threads-do-reads no|io-threads-do-reads yes|" /etc/redis/redis.conf
  fi

# Redis Service
#sed -i "s|Type=notify|Type=forking|g" /lib/systemd/system/redis-server.service
#sed -i "s|--daemonize no|--daemonize yes|g" /lib/systemd/system/redis-server.service
sed -i "s|ReadWritePaths=-/var/run|ReadWritePaths=-/run|g" /lib/systemd/system/redis-server.service

# Permissions
chown -R redis:redis /etc/redis/redis.conf
chmod 775 /etc/redis/redis.conf

# Finalize Redis Install
systemctl daemon-reload
service redis-server restart
sudo systemctl enable redis-server

# Redis Service Check
STATUS="$(systemctl is-active redis)"
if [ "${STATUS}" = "active" ]; then
  echo "PASSED: Redis is running."
  echo "REDIS=1" >> /var/log/EngineScript/install-log.txt
else
  echo "FAILED: Redis not running. Please diagnose this issue before proceeding."
  exit 1
fi
