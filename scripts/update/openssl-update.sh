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

# Download OpenSSL
cd /usr/src
# Updated URL structure for GitHub releases
wget "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz" --no-check-certificate
tar -xzf "openssl-${OPENSSL_VER}.tar.gz"
cd "openssl-${OPENSSL_VER}"

# Compile OpenSSL
chmod +x ./config
./Configure
make -j${CPU_COUNT}
#make test
make install

# Link OpenSSL
sudo touch /etc/ld.so.conf.d/openssl.conf
echo "/usr/local/lib64" >> /etc/ld.so.conf.d/openssl.conf
ldconfig
ln -s /usr/local/bin/openssl /usr/bin/
openssl version

# OpenSSL Update Completed
echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}OpenSSL ${OPENSSL_VER} installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
