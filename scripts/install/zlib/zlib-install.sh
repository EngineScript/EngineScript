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

# Return to /usr/src
cd /usr/src

# Cloudflare zlib fork (disabled)
# Disabled due to security and maintenance concerns. Keep this block for future re-enable if upstream status improves.
#if [[ -d "/usr/src/zlib-cf" ]]; then
#  rm -rf "/usr/src/zlib-cf"
#fi
#
#git clone --depth 1 https://github.com/cloudflare/zlib.git -b gcc.amd64 "/usr/src/zlib-cf"
#cd "/usr/src/zlib-cf"
#sudo ./configure --prefix=path \
#  --static \
#  --64
#make -f Makefile.in distclean

#make
#make test
#make install
#ldconfig

## zlib-ng download
#rm -rf "/usr/src/zlib-ng"
#git clone --depth 1 https://github.com/Dead2/zlib-ng -b develop "/usr/src/zlib-ng"
#cd "/usr/src/zlib-ng"
#sudo ./configure --prefix=path \
#  --zlib-compat

#make -j"${CPU_COUNT}"
#make test
#make install
#ldconfig

# Official zlib Download
# Remove existing official zlib source directory and tarball if they exist
clean_directory "/usr/src/zlib-${ZLIB_VER}"
if [[ -f "/usr/src/zlib-${ZLIB_VER}.tar.gz" ]]; then
  rm -f "/usr/src/zlib-${ZLIB_VER}.tar.gz"
fi

download_and_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz" "/usr/src/zlib-${ZLIB_VER}.tar.gz"

# Return to /usr/src
cd /usr/src
