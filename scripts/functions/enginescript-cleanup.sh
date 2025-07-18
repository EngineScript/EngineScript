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

# Cleanup

# Remove Apache and old PHP installations
apt-get remove 'apache2.*' 'php7\.0.*' 'php7\.1.*' 'php7\.2.*' 'php7\.3.*' 'php7\.4.*' 'php8\.0.*' -y

# Remove old downloads
rm -rf /usr/src/*.tar.gz*

# Remove old packages
apt clean -y
apt autoremove --purge -y
apt autoclean -y
