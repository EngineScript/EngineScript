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

#----------------------------------------------------------------------------

# Update Wordfence CLI

cd /usr/src
wget -O /usr/src https://github.com/wordfence/wordfence-cli/releases/latest/download/wordfence.deb --no-check-certificate
sudo apt install /usr/src/wordfence.deb -y
