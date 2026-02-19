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

# Prompt for EngineScript Update
    if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
        /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
    else
        echo "Skipping EngineScript update."
    fi

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Nginx Source Downloads"

# Retrieve Latest Brotli
/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Brotli"

# Retrieve Latest OpenSSL
/usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "OpenSSL"

# Retrieve Latest zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "zlib"

# Retrieve Latest PCRE2
/usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "PCRE2"

# Patch Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-patch.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Patch Nginx"

# Compile Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-compile.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Compile Nginx"

# Create Directories
/usr/local/bin/enginescript/scripts/install/nginx/nginx-create-directories.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Create Directories"

# Misc Nginx Stuff
/usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Misc Nginx Stuff"

# Tune Nginx
/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Tune Nginx"

# Cloudflare
/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cloudflare"

# Hide EngineScript Header
if [[ "${SHOW_ENGINESCRIPT_HEADER}" == "1" ]];
  then
    sed -i "s|#more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|g" /etc/nginx/globals/response-headers.conf
  else
    echo ""
fi

# Stop Nginx service before replacing binary to avoid "Text file busy" error
if systemctl is-active --quiet nginx; then
    echo "Stopping Nginx service for binary replacement..."
    systemctl stop nginx
fi

# Remove .default Files
rm -rf /etc/nginx/{*.default,*.dpkg-dist}

# Remove debug symbols
strip -s /usr/sbin/nginx*

# Assign Nginx Permissions
set_nginx_permissions

# Verify nginx configuration before starting
echo "Testing nginx configuration..."
if ! /usr/sbin/nginx -t; then
    echo "ERROR: Nginx configuration test failed!"
    echo "Please check the configuration and fix any issues before starting nginx."
    exit 1
fi

# Start Nginx Service
systemctl start nginx

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -Vv
echo ""
echo "Nginx Executable Properties:"
checksec --format=json --file=/usr/sbin/nginx --extended | jq -r

# Nginx Service Check
STATUS="$(systemctl is-active nginx)"
if [[ "${STATUS}" == "active" ]]; then
  echo "PASSED: Nginx is running."
  echo "NGINX=1" >> /var/log/EngineScript/install-log.log
else
  echo "FAILED: Nginx not running. Please diagnose this issue before proceeding."
    systemctl status nginx
    exit 1
fi
