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

#----------------------------------------------------------------------------

# Scan the entire /var/www/sites directory, which will include all WordPress sites installed on your server.
# When the filetypes match (html,css,js,json,xml,svg), brotli and gzip will compress using the strongest compression.
# This pre-compression allows the broli and gzip static functions to work within Nginx

# Brotli Compression
#find /var/www/sites -type f -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
#-o -name '*.json' -o -name '*.xml' -o -name '*.svg' \) \
#-exec brotli -kfZ {} \+

# GZip Compression
find /var/www/sites -type f -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
-o -name '*.json' -o -name '*.xml' -o -name '*.svg' \) \
-exec gzip -f --best -k {} \+
