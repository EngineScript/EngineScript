#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/scripts-variables.txt
source /home/EngineScript/enginescript-install-options.txt

#----------------------------------------------------------------------------
#
# Scan the entire /var/www/sites directory, which will include all WordPress sites installed on your server.
# When the filetypes match (html,css,js,json,xml,svg), brotli and gzip will compress using the strongest compression.
# This pre-compression allows the broli and gzip static functions to work within Nginx
#

# Brotli Compression
#find /var/www/sites -type f -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
#-o -name '*.json' -o -name '*.xml' -o -name '*.svg' \) \
#-exec brotli -kfZ {} \+

# GZip Compression
find /var/www/sites -type f -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
-o -name '*.json' -o -name '*.xml' -o -name '*.svg' \) \
-exec gzip -f --best -k {} \+
