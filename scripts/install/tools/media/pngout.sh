#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
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

# Install pngout

# Retrieve Latest Version
cd /usr/src
wget https://static.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz --no-check-certificate
tar -xf pngout-${PNGOUT_VER}-linux.tar.gz
mkdir -p /bin/pngout

# Install 32-BIT or 64-BIT
if [ ${BIT_TYPE} == 'x86_64' ];
  then
    # 64-bit
    cp /usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout /bin/pngout
  else
    # 32-bit
    cp /usr/src/pngout-${PNGOUT_VER}-linux/i686/pngout /bin/pngout
fi
