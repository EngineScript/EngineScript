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

# Remove existing Testssl.sh directory if it exists
if [ -d "/usr/local/bin/testssl.sh" ]; then
  rm -rf /usr/local/bin/testssl.sh
fi

# Install Testssl.sh
git clone https://github.com/testssl/testssl.sh.git /usr/local/bin/testssl.sh

# Permissions
find /usr/local/bin/testssl.sh -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/testssl.sh
find /usr/local/bin/testssl.sh -type f -iname "*.sh" -exec chmod +x {} \;

# Return to /usr/src
cd /usr/src
