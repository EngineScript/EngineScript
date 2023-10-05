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

# Remove Old Version
rm -rf /usr/local/bin/testssl.sh

# Install Testssl.sh
git clone https://github.com/drwetter/testssl.sh.git /usr/local/bin/testssl.sh

# Permissions
find /usr/local/bin/testssl.sh -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/testssl.sh
find /usr/local/bin/testssl.sh -type f -iname "*.sh" -exec chmod +x {} \;
