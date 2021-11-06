#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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
wget https://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz
tar -xf pngout-20150319-linux.tar.gz

# Install 32-BIT or 64-BIT
if [ ${BIT_TYPE} == 'x86_64' ];
  then
    # 64-bit
    cp pngout-20150319-linux/x86_64/pngout /bin/pngout
  else
    # 32-bit
    cp pngout-20150319-linux/i686/pngout /bin/pngout
fi
