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

# Wordfence CLI Malware scanner

# Install
cd /usr/local/src
wget https://github.com/wordfence/wordfence-cli/releases/download/v${WORDFENCE_CLI_VER}/wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz --no-check-certificate
tar xvzf wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz
mkdir -p /home/EngineScript/wordfence-scan-results
mkdir -p ~/.cache/wordfence
mkdir -p ~/.config/wordfence
chmod 775 ~/.cache/wordfence
touch ~/.config/wordfence/wordfence-cli.ini

# Configuration
# Create your token at https://www.wordfence.com/products/wordfence-cli/
cat >>~/.config/wordfence/wordfence-cli.ini <<EOL
[SCAN]
license = ${WORDFENCE_CLI_TOKEN}
cache_directory = ~/.cache/wordfence
workers = 1


EOL

cat ~/.config/wordfence/wordfence-cli.ini

echo ""
echo ""
echo "============================================================"
echo ""
echo "${BOLD}Wordfence CLI installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
