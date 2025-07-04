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

# Return to /usr/src directory
cd /usr/src

# Download and extract OpenSSL
wget "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz" -O "/usr/src/openssl-${OPENSSL_VER}.tar.gz" --no-check-certificate || { echo "Error: Failed to download OpenSSL."; exit 1; }
tar -xzf "/usr/src/openssl-${OPENSSL_VER}.tar.gz" || { echo "Error: Failed to extract OpenSSL."; exit 1; }
