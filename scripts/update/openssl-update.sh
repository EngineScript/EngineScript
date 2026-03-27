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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Download and extract OpenSSL
download_and_extract \
    "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz" \
    "/usr/src/openssl-${OPENSSL_VER}.tar.gz" \
    "/usr/src" 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "OpenSSL Download"

cd "/usr/src/openssl-${OPENSSL_VER}"

# Compile OpenSSL
chmod +x ./config
./Configure 2>> /tmp/enginescript_install_errors.log
make -j"${CPU_COUNT}" 2>> /tmp/enginescript_install_errors.log
#make test
make install 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "OpenSSL Compilation"

# Link OpenSSL
sudo touch /etc/ld.so.conf.d/openssl.conf
echo "/usr/local/lib64" >> /etc/ld.so.conf.d/openssl.conf
ldconfig 2>> /tmp/enginescript_install_errors.log
ln -s /usr/local/bin/openssl /usr/bin/
openssl version
print_last_errors
debug_pause "OpenSSL Linking"

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
