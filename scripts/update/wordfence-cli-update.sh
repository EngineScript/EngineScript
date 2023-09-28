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

#----------------------------------------------------------------------------

# Update Wordfence CLI

rm -rf /usr/local/src/Wordfence-CLI/wordfence
cd /usr/src
wget -O /usr/src/wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz https://github.com/wordfence/wordfence-cli/releases/download/v${WORDFENCE_CLI_VER}/wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz --no-check-certificate
tar -xvf wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz
mv /usr/src/wordfence /usr/local/src/Wordfence-CLI/wordfence
