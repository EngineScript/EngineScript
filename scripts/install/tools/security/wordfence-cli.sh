#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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
wget -O /usr/src https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb --no-check-certificate
sudo apt install /usr/src/wordfence.deb -y

# Old install method prior to version 2.0+
#mkdir -p /usr/local/src/Wordfence-CLI/
#rm -rf /usr/local/src/Wordfence-CLI/wordfence
#cd /usr/src
#wget -O /usr/src/wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz https://github.com/wordfence/wordfence-cli/releases/download/v${WORDFENCE_CLI_VER}/wordfence-${WORDFENCE_CLI_VER}.tar.gz --no-check-certificate
#tar -xvf wordfence_${WORDFENCE_CLI_VER}_amd64_linux_exec.tar.gz
#mv /usr/src/wordfence-${WORDFENCE_CLI_VER} /usr/local/src/Wordfence-CLI/wordfence

# Make Results Directory
mkdir -p /home/EngineScript/wordfence-scan-results

# Make Cache Directory
mkdir -p ~/.cache/wordfence
chmod 775 ~/.cache/wordfence

# Configuration
# Old config method prior to version 2.0+
# Create your token at https://www.wordfence.com/products/wordfence-cli/
#mkdir -p ~/.config/wordfence
#touch ~/.config/wordfence/wordfence-cli.ini
#cat >>~/.config/wordfence/wordfence-cli.ini <<EOL
#[SCAN]
#license = ${WORDFENCE_CLI_TOKEN}
#cache_directory = ~/.cache/wordfence
#workers = 1
#
#
#EOL
#
#cat ~/.config/wordfence/wordfence-cli.ini

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
