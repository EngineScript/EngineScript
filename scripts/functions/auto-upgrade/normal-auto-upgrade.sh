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

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check if INSTALL_ENGINESCRIPT_PLUGINS exists in the options file, add it if missing
if ! grep -q "INSTALL_ENGINESCRIPT_PLUGINS=" /home/EngineScript/enginescript-install-options.txt; then
  echo "Adding INSTALL_ENGINESCRIPT_PLUGINS option to install options file..."
  # Find the line after AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION and insert the new option
  sed -i '/AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION=/a \
\
# Install EngineScript Custom Plugins\
# When enabled, EngineScript will install its two custom plugins during site creation:\
# 1. Simple WP Optimizer - Basic WordPress optimizations (header cleanup, etc.)\
# 2. Simple Site Exporter - Makes it easy to export sites to new EngineScript servers\
# Note: This does NOT affect other recommended plugins (Nginx Helper, Redis, etc.)\
INSTALL_ENGINESCRIPT_PLUGINS=1' /home/EngineScript/enginescript-install-options.txt
fi