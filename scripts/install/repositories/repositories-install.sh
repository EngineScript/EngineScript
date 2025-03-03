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

# Canonical Server Team Backports
add-apt-repository -yn ppa:canonical-server/server-backports

# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# ElasticSearch
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

# GeoIP
add-apt-repository -yn ppa:maxmind/ppa

# Git
add-apt-repository -yn ppa:git-core/ppa

# Google gcloud CLI
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Grafana
curl -fsSL https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Hurl
add-apt-repository -yn ppa:lepapareil/hurl

# Kernel Updates
# may be temporary
#add-apt-repository -yn ppa:tuxinvader/lts-mainline
#add-apt-repository -yn ppa:tuxinvader/lts-mainline-longterm

# Node.js
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -

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

# Utilities
#add-apt-repository -yn ppa:sergey-dryabzhinsky/packages

# Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Version Specific Repositories
UBUNTU_VERSION="$(lsb_release -sr)"
if [ "${UBUNTU_VERSION}" = 22.04 ];
  then
    # Canonical Server Team Backports

    # phpMyAdmin
    #add-apt-repository -yn ppa:phpmyadmin/ppa

  else
    echo "Skipping repos that don't support Ubuntu Noble 24.04"
fi

echo "Repo install completed on ${VARIABLES_DATE}"
