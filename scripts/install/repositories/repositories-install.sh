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

# Helper function for retrying add-apt-repository up to 3 times with 5s delay
retry_add_ppa() {
  local ppa="$1"
  local max_retries=3
  local delay=5
  local attempt=1
  while [ $attempt -le $max_retries ]; do
    add-apt-repository -yn "$ppa" && return 0
    echo "Attempt $attempt to add $ppa failed. Retrying in $delay seconds..."
    attempt=$((attempt+1))
    sleep $delay
  done
  echo "Failed to add $ppa after $max_retries attempts. Exiting."
  exit 1
}

#----------------------------------------------------------------------------------
# Start Main Script

# Canonical Server Team Backports
retry_add_ppa ppa:canonical-server/server-backports

# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# ElasticSearch
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

# GeoIP
retry_add_ppa ppa:maxmind/ppa

# Git
retry_add_ppa ppa:git-core/ppa

# Google gcloud CLI
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Grafana
curl -fsSL https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Hurl
retry_add_ppa ppa:lepapareil/hurl

# Kernel Updates
# may be temporary
#add-apt-repository -yn ppa:tuxinvader/lts-mainline
#add-apt-repository -yn ppa:tuxinvader/lts-mainline-longterm

# PHP
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
retry_add_ppa ppa:ondrej/php

# Python
retry_add_ppa ppa:deadsnakes/ppa

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
retry_add_ppa universe

# Utilities
#add-apt-repository -yn ppa:sergey-dryabzhinsky/packages

# Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Version Specific Repositories
UBUNTU_VERSION="$(lsb_release -sr)"
if [ "${UBUNTU_VERSION}" = "22.04" ]; then
  echo "Not adding any additional repositories for Ubuntu Jammy 22.04"
  # phpMyAdmin
  #add-apt-repository -yn ppa:phpmyadmin/ppa
else
  echo "Skipping repos that don't support Ubuntu Noble 24.04"
fi
