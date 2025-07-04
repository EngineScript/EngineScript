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

# ACME.sh Install
curl https://get.acme.sh | sh

# Cloudflare Keys
export CF_Key="${CF_GLOBAL_API_KEY}"
export CF_Email="${CF_ACCOUNT_EMAIL}"

# Register ZeroSSL
# Using the user's Cloudflare email address since it's less fields they are required to fill out in the option file and would more than likely be the same address.
/root/.acme.sh/acme.sh --register-account -m "${CF_ACCOUNT_EMAIL}"

/root/.acme.sh/acme.sh --upgrade --auto-upgrade
