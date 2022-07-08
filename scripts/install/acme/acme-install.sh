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

# Notes on ACME.sh
# ACME.sh is currently in the process of switching to ZeroSSL.
# For the moment, we'll continue to use Let's Encrypt.
# Things may need to change in the future.
# https://github.com/acmesh-official/acme.sh/wiki/Server
# https://github.com/acmesh-official/acme.sh/wiki/Change-default-CA-to-ZeroSSL
# https://github.com/acmesh-official/acme.sh/issues/3556

# ACME.sh Install
curl https://get.acme.sh | sh

# Cloudflare Keys
export CF_Key="${CF_GLOBAL_API_KEY}"
export CF_Email="${CF_ACCOUNT_EMAIL}"

/root/.acme.sh/acme.sh --upgrade --auto-upgrade
