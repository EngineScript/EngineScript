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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

# Check if Ubuntu is 20.04. If not, exit.
UBUNTU_CODENAME="$(lsb_release -sc)"

if [ "${UBUNTU_CODENAME}" != focal ];
  then
    echo "ALERT:"
    echo "EngineScript does not support Ubuntu ${UBUNTU_CODENAME}. We recommend using 20.04 focal"
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Enginescript is and always will be a personal project that I started as a means
# to increase my understanding of Linux and hosting technology. Rather than try to
# obfuscate the code to make things harder to comprehend, I've tried to keep things
# relatively clear for somebody diving into it to increase their own knowledge.
#
# My first real attempts at doing anything on my own involved countless hours of reading,
# failures, and scouring the internet to see how others were doing things. Much of my
# original inspiration is solely due to the amazing work of George Liu, creater of Centminmod.
# His work showed a lot of people, myself included, just how cool hosting technology can be.
#
# Hopefully, EngineScript has some things that you may find useful. The path forward from here
# is a neverending one. I wish you luck on your journey into Linux, Nginx, WordPress, and
# whatever else interests you.
#
# ---WARNING---
# EngineScript does a lot of hand-holding when it comes to site and database creation.
# We've tried to find a balance between user autonomy and system automation. Unfortunately,
# this automation sometimes comes at the expense of security. EngineScript automatically
# generates and stores many passwords for you, this includes storing mysql database credentials.
#
# Finally, EngineScript is very experimental in nature. We use a lot of bleeding-edge
# technology. This includes using Nginx Mainline branch instead of Stable branch. We also use a number
# of PPAs from developers that supply packages outside of the standard Ubuntu repositories.
# Some of these packages include backports, some of them are just more up-to-date.
# If you're looking for the most secure server environment possible, EngineScript
# is probably not what you're looking for.

# Install Required Packages for Script
apt update
apt install -y boxes git nano pwgen software-properties-common tzdata unattended-upgrades
apt full-upgrade -y
apt dist-upgrade -y

# EngineScript Git Clone
rm -rf /usr/local/bin/enginescript
git clone --depth 1 https://github.com/EngineScript/EngineScript.git -b master /usr/local/bin/enginescript

# EngineScript Permissions
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;

chown -hR root:root /usr/local/bin/enginescript

# Create EngineScript Home Directory
mkdir -p /home/EngineScript/config-backups/nginx
mkdir -p /home/EngineScript/config-backups/php
mkdir -p /home/EngineScript/mysql-credentials
mkdir -p /home/EngineScript/site-backups
mkdir -p /home/EngineScript/sites-list

apt update
apt full-upgrade -y
apt dist-upgrade -y
apt clean -y
apt autoremove --purge -y
apt autoclean -y

if [ -f "/home/EngineScript/enginescript-install-options.txt" ]
  then
    echo ""
    echo ""
    echo ""
    echo "Initial setup is complete."
    echo "Change the options in /home/EngineScript/enginescript-install-options.txt"
    echo "Edit the file and upload via FTP or run command \"nano /home/EngineScript/enginescript-install-options.txt\""
    echo ""
    echo "After changing options file, run \"bash /usr/local/bin/enginescript/enginescript-install.sh\""
    echo ""
    echo ""
  else
    cp -p /usr/local/bin/enginescript/home/enginescript-install-options.txt /home/EngineScript/enginescript-install-options.txt
    echo ""
    echo ""
    echo ""
    echo "Initial setup is complete."
    echo "Change the options in /home/EngineScript/enginescript-install-options.txt"
    echo "Edit the file and upload via FTP or run command \"nano /home/EngineScript/enginescript-install-options.txt\""
    echo ""
    echo "After changing options file, run \"bash /usr/local/bin/enginescript/enginescript-install.sh\""
    echo ""
    echo ""
fi

echo -e "Server needs to restart" | boxes -a c -d shell -p a1l2
echo "Server will restart in 10 seconds"
sleep 10
echo "Restarting..."
shutdown -r now
