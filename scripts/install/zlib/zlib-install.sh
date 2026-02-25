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

# Official zlib Download
# Remove existing official zlib source directory and tarball if they exist
clean_directory "/usr/src/zlib-${ZLIB_VER}"
if [[ -f "/usr/src/zlib-${ZLIB_VER}.tar.gz" ]]; then
  rm -f "/usr/src/zlib-${ZLIB_VER}.tar.gz"
fi

download_and_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz" "/usr/src/zlib-${ZLIB_VER}.tar.gz"

# Return to /usr/src
cd /usr/src
