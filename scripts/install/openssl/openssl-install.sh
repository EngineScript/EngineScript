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

# Download OpenSSL
cd /usr/src
wget https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz --no-check-certificate
#apt remove openssl -y
tar -xvzf openssl-${OPENSSL_VER}.tar.gz

# Compile OpenSSL
#cd openssl-${OPENSSL_VER}
#chmod +x ./config
#./Configure
#make -j${CPU_COUNT}
#make test
#make install

# Link OpenSSL
#sudo touch /etc/ld.so.conf.d/openssl.conf
#echo "/usr/local/lib64" >> /etc/ld.so.conf.d/openssl.conf
#ldconfig
#ln -s /usr/local/bin/openssl /usr/bin/
#openssl version

# Reinstall Dependencies
# A few packages were uninstalled when we removed OpenSSL. Let's add them back.
#apt install -qy ca-certificates libruby3.0 python2-pip-whl python3-certifi python3-docker python3-httplib2 python3-influxdb python3-launchpadlib python3-lazr.restfulclient python3-pip python3-requests python3-requests-unixsocket python3-software-properties rake ruby ruby-dev ruby-rubygems ruby3.0 ruby3.0-dev rubygems-integration software-properties-common

# OpenSSL Installation Completed
#echo ""
#echo ""
#echo "============================================================="
#echo ""
#echo "${BOLD}OpenSSL ${OPENSSL_VER} installed.${NORMAL}"
#echo ""
#echo "============================================================="
#echo ""
#echo ""

sleep 5
