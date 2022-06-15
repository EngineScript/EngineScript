#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# dos2unix
# We do this in-case the user is a novice and uploaded the options file using a basic Windows text editor.
dos2unix /home/EngineScript/enginescript-install-options.txt

# Permissions
# Just in case you changed any files and changed Permissions
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/enginescript

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Reboot Warning
echo -e "ATTENTION\n\nServer needs to reboot at the end of this script.\nEnter command es.menu after reboot to continue.\n\nScript will continue in 5 seconds..." | boxes -a c -d shell -p a1l2
sleep 5

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 1000 ];
  then
    echo "WARNING: Total server memory is low."
    echo "It is recommended that a server running EngineScript has at least 2GB total memory."
    echo "EngineScript will attempt to configure memory settings that will work for a 1GB server, but performance is not guaranteed."
    echo "You may need to manually change memory limits in PHP and MariaDB."
    sleep 10
  else
    echo "80% of total server memory: ${SERVER_MEMORY_TOTAL_80}"
fi

# Set Time Zone
dpkg-reconfigure tzdata

# Set Unattended Upgrades
dpkg-reconfigure unattended-upgrades

# HWE
apt install --install-recommends linux-generic-hwe-22.04 -y

sleep 3
# Add User
useradd -m -s /bin/bash -c "Administrative User" ${WEBMIN_USERNAME} ; echo -e "${WEBMIN_PASSWORD}\n${WEBMIN_PASSWORD}" | passwd ${WEBMIN_USERNAME}

# Remove Password Expiration
chage -I -1 -m 0 -M 99999 -E -1 root
chage -I -1 -m 0 -M 99999 -E -1 ${WEBMIN_USERNAME}

# Set Sudo
usermod -aG sudo "${WEBMIN_USERNAME}"
echo "User account ${BOLD}${WEBMIN_USERNAME}${NORMAL} has been created." | boxes -a c -d shell -p a1l2

# Install Check
touch /home/EngineScript/install-log.txt
source /home/EngineScript/install-log.txt

# Repositories
if [ "${REPOS}" = 1 ];
  then
    echo "REPOS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/repositories/repositories-install.sh
    echo "REPOS=1" >> /home/EngineScript/install-log.txt
fi

# Block Unwanted Packages
if [ "${BLOCK}" = 1 ];
  then
    echo "BLOCK script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/block/package-block.sh
    echo "BLOCK=1" >> /home/EngineScript/install-log.txt
fi

# Update & Upgrade
apt update
apt full-upgrade -y
apt dist-upgrade -y

# Remove Preinstalled Software
if [ "${REMOVES}" = 1 ];
  then
    echo "REMOVES script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/removes/remove-preinstalled.sh
    echo "REMOVES=1" >> /home/EngineScript/install-log.txt
fi

# Install Dependencies
if [ "${DEPENDS}" = 1 ];
  then
    echo "DEPENDS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/depends/depends-install.sh
    echo "DEPENDS=1" >> /home/EngineScript/install-log.txt
fi

# Enginescript Aliases
if [ "${ALIAS}" = 1 ];
  then
    echo "ALIAS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/alias/enginescript-alias-install.sh
    echo "ALIAS=1" >> /home/EngineScript/install-log.txt
fi

# ACME.sh
if [ "${ACME}" = 1 ];
  then
    echo "ACME.sh script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/acme/acme-install.sh
    echo "ACME=1" >> /home/EngineScript/install-log.txt
fi

# GCC
if [ "${GCC}" = 1 ];
  then
    echo "GCC script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/gcc/gcc-install.sh
    echo "GCC=1" >> /home/EngineScript/install-log.txt
fi

# OpenSSL
if [ "${OPENSSL}" = 1 ];
  then
    echo "OPENSSL script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh
    echo "OPENSSL=1" >> /home/EngineScript/install-log.txt
fi

# Jemalloc
#if [ "${JEMALLOC}" = 1 ];
#  then
#    echo "JEMALLOC script has already run."
#  else
#    /usr/local/bin/enginescript/scripts/install/jemalloc/jemalloc-install.sh
#    echo "JEMALLOC=1" >> /home/EngineScript/install-log.txt
#fi

# Swap
if [ "${SWAP}" = 1 ];
  then
    echo "SWAP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/swap/swap-install.sh
    echo "SWAP=1" >> /home/EngineScript/install-log.txt
fi

# Kernel Tweaks
if [ "${KERNEL_TWEAKS}" = 1 ];
  then
    echo "KERNEL TWEAKS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh
    echo "KERNEL_TWEAKS=1" >> /home/EngineScript/install-log.txt
fi

# Kernel Samepage Merging
if [ "${KSM}" = 1 ];
  then
    echo "KSM script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/ksm.sh
    echo "KSM=1" >> /home/EngineScript/install-log.txt
fi

# Raising System File Limits
if [ "${SFL}" = 1 ];
  then
    echo "SSTEM FILE LIMITS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/system-misc/file-limits.sh
    echo "SFL=1" >> /home/EngineScript/install-log.txt
fi

# Kernel Update
#if [ "${KERNEL_UPDATE}" = 1 ];
#  then
#    echo "KERNEL UPDATE script has already run."
#  else
#    /usr/local/bin/enginescript/scripts/install/kernel/kernel-update.sh
#    echo "KERNEL_UPDATE=1" >> /home/EngineScript/install-log.txt
#fi

# NTP
if [ "${NTP}" = 1 ];
  then
    echo "NTP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/systemd/timesyncd.sh
    echo "NTP=1" >> /home/EngineScript/install-log.txt
fi

# THP
if [ "${THP}" = 1 ];
  then
    echo "THP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/systemd/thp.sh
    echo "THP=1" >> /home/EngineScript/install-log.txt
fi

# Python
if [ "${PYTHON}" = 1 ];
  then
    echo "PYTHON script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/python/python-install.sh
    echo "PYTHON=1" >> /home/EngineScript/install-log.txt
fi

# PCRE
if [ "${PCRE}" = 1 ];
  then
    echo "PCRE script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh
    echo "PCRE=1" >> /home/EngineScript/install-log.txt
fi

# zlib
if [ "${ZLIB}" = 1 ];
  then
    echo "ZLIB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh
    echo "ZLIB=1" >> /home/EngineScript/install-log.txt
fi

# libdeflate
if [ "${LIBDEFLATE}" = 1 ];
  then
    echo "LIBDEFLATE script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/libdeflate/libdeflate-install.sh
    echo "LIBDEFLATE=1" >> /home/EngineScript/install-log.txt
fi

# liburing
if [ "${LIBURING}" = 1 ];
  then
    echo "LIBURING script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh
    echo "LIBURING=1" >> /home/EngineScript/install-log.txt
fi

# UFW
if [ "${UFW}" = 1 ];
  then
    echo "UFW script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/ufw/ufw-install.sh
    echo "UFW=1" >> /home/EngineScript/install-log.txt
fi

# Cron
if [ "${CRON}" = 1 ];
  then
    echo "CRON script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/cron/cron-install.sh
    echo "CRON=1" >> /home/EngineScript/install-log.txt
fi

# MariaDB
if [ "${MARIADB}" = 1 ];
  then
    echo "MARIADB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-install.sh
    echo "MARIADB=1" >> /home/EngineScript/install-log.txt
fi

# PHP
if [ "${PHP}" = 1 ];
  then
    echo "PHP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/php/php-install.sh
    echo "PHP=1" >> /home/EngineScript/install-log.txt
fi

# Redis
if [ "${REDIS}" = 1 ];
  then
    echo "REDIS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/redis/redis-install.sh
    echo "REDIS=1" >> /home/EngineScript/install-log.txt
fi

# Nginx
if [ "${NGINX}" = 1 ];
  then
    echo "NGINX script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/nginx/nginx-install.sh
    echo "NGINX=1" >> /home/EngineScript/install-log.txt
fi

# Tools
if [ "${TOOLS}" = 1 ];
  then
    echo "TOOLS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/tools/tools-install.sh
    echo "TOOLS=1" >> /home/EngineScript/install-log.txt
fi

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# Server Reboot
clear

echo -e "${BOLD}Server needs to reboot.${NORMAL}\n\nEnter command ${BOLD}es.menu${NORMAL} after reboot to continue.\n" | boxes -a c -d shell -p a1l2
sleep 15
clear

echo -e "Server rebooting now...\n\n${NORMAL}When reconnected, use command ${BOLD}es.menu${NORMAL} to start EngineScript.\nSelect option 1 to create a new vhost configuration on your server.\n\n${BOLD}Bye! Manually reconnect in 30 seconds.\n" | boxes -a c -d shell -p a1l2
shutdown -r now
