#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt



#----------------------------------------------------------------------------------
# Start Main Script

# EngineScript Update (Makes sure we're installing latest Nginx)
/usr/local/bin/enginescript/scripts/update/enginescript-update.sh

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh

# Retrieve Latest Brotli
/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh

# Retrieve Latest OpenSSL
/usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh

# Retrieve Latest Cloudflare Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh

# Retrieve Latest PCRE2
/usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh

# Patch Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-patch.sh

# Compile Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-compile.sh

# Create Directories
/usr/local/bin/enginescript/scripts/install/nginx/nginx-create-directories.sh

# Misc Nginx Stuff
/usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh

# Tune Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh

# Cloudflare
/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare.sh

# Hide EngineScript Header
if [ "${SHOW_ENGINESCRIPT_HEADER}" = 1 ];
  then
    sed -i "s|#more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|g" /etc/nginx/globals/response-headers.conf
  else
    echo ""
fi

if [ "${NGINX_SECURE_ADMIN}" = 1 ];
  then
    sed -i "s|#satisfy any|satisfy any|g" /etc/nginx/admin/admin.localhost.conf
    sed -i "s|#auth_basic|auth_basic|g" /etc/nginx/admin/admin.localhost.conf
    sed -i "s|#allow |allow |g" /etc/nginx/admin/admin.localhost.conf
  else
    echo ""
fi

service nginx stop

# Remove .default Files
rm -rf /etc/nginx/{*.default,*.dpkg-dist}

# Remove debug symbols
strip -s /usr/sbin/nginx*

service nginx start

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -Vv
echo ""
echo "Nginx Executable Properties:"
checksec --format=json --file=/usr/sbin/nginx --extended | jq -r
