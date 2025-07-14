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

# GCC

# Remove previous GCC alternatives
update-alternatives --remove-all gcc
echo "Ignore the error above on fresh installs."

UBUNTU_VERSION="$(lsb_release -sr)"
if [[ "${UBUNTU_VERSION}" == "24.04" ]];
  then
    # Install GCC for Ubuntu 24.04
    apt install g++-13 gcc-13 g++-14 gcc-14 -y

    # Create new GCC alternatives
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100 --slave /usr/bin/g++ g++ /usr/bin/g++-14 --slave /usr/bin/gcov gcov /usr/bin/gcov-14
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 90 --slave /usr/bin/g++ g++ /usr/bin/g++-13 --slave /usr/bin/gcov gcov /usr/bin/gcov-13
fi
