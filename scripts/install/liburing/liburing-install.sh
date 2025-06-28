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

# Return to /usr/src
cd /usr/src

# Official liburing Download
wget -O "/usr/src/liburing-${LIBURING_VER}.tar.gz" "https://github.com/axboe/liburing/archive/refs/tags/liburing-${LIBURING_VER}.tar.gz" --no-check-certificate
tar -xzf "/usr/src/liburing-${LIBURING_VER}.tar.gz"
cd "/usr/src/liburing-liburing-${LIBURING_VER}"

# Compile liburing
make -j"${CPU_COUNT}"

# Install liburing
make install

# Old Method
#rm -rf /usr/src/liburing
#git clone --depth 1 https://github.com/axboe/liburing -b master /usr/src/liburing
#cd /usr/src/liburing
#make -j"${CPU_COUNT}"
#make test
#make install

# Return to /usr/src
cd /usr/src
