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

# Install pngout

# Retrieve Latest Version
wget -O "/usr/src/pngout-${PNGOUT_VER}-linux.tar.gz" "https://static.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz" --no-check-certificate
tar -xzf "/usr/src/pngout-${PNGOUT_VER}-linux.tar.gz"

# Install 32-BIT or 64-BIT
if [[ "${BIT_TYPE}" == 'x86_64' ]];
  then
    # 64-bit
    cp "/usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout" /bin
  else
    # 32-bit
    cp "/usr/src/pngout-${PNGOUT_VER}-linux/i686/pngout" /bin
fi

# Return to /usr/src
cd /usr/src
