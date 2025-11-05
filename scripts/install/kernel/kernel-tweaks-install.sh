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

# Kernel Tweaks
cp -rf /usr/local/bin/enginescript/config/etc/sysctl.d/60-enginescript.conf /etc/sysctl.d/60-enginescript.conf
chown -R root:root /etc/sysctl.d/60-enginescript.conf
chmod 0664 /etc/sysctl.d/60-enginescript.conf

# KTLS (testing)
echo tls >/etc/modules-load.d/tls.conf

# Enable Kernel Tweaks
sysctl -e -p /etc/sysctl.d/60-enginescript.conf
sysctl --system
