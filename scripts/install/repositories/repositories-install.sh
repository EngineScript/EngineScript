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

# GeoIP
add-apt-repository -yn ppa:maxmind/ppa

# Git
add-apt-repository -yn ppa:git-core/ppa

# Kernel Updates
# may be temporary
#add-apt-repository -yn ppa:tuxinvader/lts-mainline
#add-apt-repository -yn ppa:tuxinvader/lts-mainline-longterm

# PHP
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
add-apt-repository -yn ppa:ondrej/php

# Python
add-apt-repository -yn ppa:deadsnakes/ppa

# Redis
#add-apt-repository -yn ppa:redislabs/redis
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

# Rob Savoury Backports
#add-apt-repository -yn ppa:savoury1/backports
#add-apt-repository -yn ppa:savoury1/build-tools
#add-apt-repository -yn ppa:savoury1/curl34
#add-apt-repository -yn ppa:savoury1/encryption
#add-apt-repository -yn ppa:savoury1/ffmpeg4
#add-apt-repository -yn ppa:savoury1/fonts
#add-apt-repository -yn ppa:savoury1/gpg
#add-apt-repository -yn ppa:savoury1/graphics
#add-apt-repository -yn ppa:savoury1/multimedia
#add-apt-repository -yn ppa:savoury1/python
#add-apt-repository -yn ppa:savoury1/utilities

# Universe
add-apt-repository -yn universe

UBUNTU_VERSION="$(lsb_release -sr)"
if [ "${UBUNTU_VERSION}" = 22.04 ];
  then
    # Canonical Server Team Backports
    add-apt-repository -yn ppa:canonical-server/server-backports

    # phpMyAdmin
    #add-apt-repository -yn ppa:phpmyadmin/ppa

  else
    echo "Skipping repos that don't support Ubuntu Noble 24.04"
fi

# Utilities
#add-apt-repository -yn ppa:sergey-dryabzhinsky/packages

echo "Repo install completed on ${VARIABLES_DATE}"
