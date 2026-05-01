#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
return_to_src

# Official liburing Download
download_and_extract "https://github.com/axboe/liburing/archive/refs/tags/liburing-${LIBURING_VER}.tar.gz" "/usr/src/liburing-${LIBURING_VER}.tar.gz"
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
return_to_src
