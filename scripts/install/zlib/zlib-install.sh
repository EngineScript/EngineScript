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

# Return to /usr/src
cd /usr/src

# Cloudflare zlib Download
# Remove existing Zlib-CF directory if it exists
if [ -d "/usr/src/zlib-cf" ]; then
  rm -rf "/usr/src/zlib-cf"
fi

# Clone Zlib-CF
git clone --depth 1 https://github.com/cloudflare/zlib.git -b gcc.amd64 "/usr/src/zlib-cf"
cd "/usr/src/zlib-cf"
sudo ./configure --prefix=path \
  --static \
  --64
make -f Makefile.in distclean

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
wget -O "/usr/src/zlib-${ZLIB_VER}.tar.gz" "https://www.zlib.net/zlib-${ZLIB_VER}.tar.gz" --no-check-certificate
tar -xzvf "/usr/src/zlib-${ZLIB_VER}.tar.gz"

# Return to /usr/src
cd /usr/src
