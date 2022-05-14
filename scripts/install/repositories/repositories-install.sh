#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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

# Backports
#add-apt-repository -yn ppa:savoury1/backports

# Build Tools
#add-apt-repository -yn ppa:savoury1/build-tools

# Canonical Partners
add-apt-repository "deb http://archive.canonical.com/ubuntu $(lsb_release -sc) partner"

# Curl
#add-apt-repository -yn ppa:savoury1/curl34

# Encryption
#add-apt-repository -yn ppa:savoury1/encryption

# ffmpeg-4
#add-apt-repository -yn ppa:savoury1/ffmpeg4

# GCC

# GeoIP
add-apt-repository -yn ppa:maxmind/ppa

# GPG
#add-apt-repository -yn ppa:savoury1/gpg

# Kernel Updates
# may be temporary
#add-apt-repository -yn ppa:tuxinvader/lts-mainline
#add-apt-repository -yn ppa:tuxinvader/lts-mainline-longterm

# Multimedia
#add-apt-repository -yn ppa:savoury1/multimedia

# PHP
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
add-apt-repository -yn ppa:ondrej/php

# phpMyAdmin
add-apt-repository -yn ppa:phpmyadmin/ppa

# Python
add-apt-repository -yn ppa:deadsnakes/ppa
#add-apt-repository -yn ppa:savoury1/python

# Redis
add-apt-repository -yn ppa:redislabs/redis

# Universe
add-apt-repository -yn universe

# Utilities
#add-apt-repository -yn ppa:savoury1/utilities
#add-apt-repository -yn ppa:sergey-dryabzhinsky/packages
