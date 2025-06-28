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

# Debug pause function
function debug_pause() {
  if [ "${DEBUG_INSTALL}" = "1" ]; then
    local last_step=${1:-"Unknown step"}
    while true; do
      echo -e "\n[DEBUG] Completed step: ${last_step}"
      echo -e "[DEBUG] Press Enter to continue, or type 'exit' to stop the install."
      echo -e "If you encountered errors above, you can copy the error text for a GitHub bug report."
      echo -e "For more server details, run: es.debug"
      read -p "[DEBUG] Continue or exit? (Enter/exit): " user_input
      if [ -z "$user_input" ]; then
        break
      elif [[ "$user_input" =~ ^[Ee][Xx][Ii][Tt]$ ]]; then
        echo -e "\nExiting install script as requested."
        exit 1
      else
        echo "Please press Enter to continue or type 'exit' to stop."
      fi
    done
  fi
}

# Print errors from the last script section if any
function print_last_errors() {
  # Always append errors to persistent log if any
  if [ -s /tmp/enginescript_install_errors.log ]; then
    cat /tmp/enginescript_install_errors.log >> /var/log/EngineScript/install-error-log.txt
  fi
  # Only show errors to user if debug mode is enabled
  if [ "${DEBUG_INSTALL}" = "1" ] && [ -s /tmp/enginescript_install_errors.log ]; then
    echo -e "\n\n==============================================================="
    echo -e "[DEBUG] ERRORS FROM LAST STEP:"
    cat /tmp/enginescript_install_errors.log
    echo -e "[END OF ERRORS]"
    echo -e "If you encounter errors and want to submit a GitHub issue, please run: es.debug"
    echo -e "===============================================================\n\n"
  fi
  # Always clear the temp log for the next step
  > /tmp/enginescript_install_errors.log
}

# Nginx Source Downloads
/usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Nginx Source Downloads"

# Brotli
/usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Brotli"

# Retrieve Latest Cloudflare Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cloudflare Zlib"

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

# Create Nginx Directories
/usr/local/bin/enginescript/scripts/install/nginx/nginx-create-directories.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Create Nginx Directories"

# Misc Nginx Stuff
/usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Misc Nginx Stuff"

# Tune Nginx FastCGI
/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Tune Nginx FastCGI"

# Backup Nginx
/usr/local/bin/enginescript/scripts/functions/backup/nginx-backup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Backup Nginx"

# Cloudflare
/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cloudflare"

# SSL
/usr/local/bin/enginescript/scripts/install/nginx/nginx-ssl.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "SSL"

# Assign Admin Password
/usr/local/bin/enginescript/scripts/install/nginx/nginx-admin-password.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Admin Password"

# Install Nginx Service
/usr/local/bin/enginescript/scripts/install/nginx/nginx-service.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Nginx Service"

# Hide EngineScript Header
if [ "${SHOW_ENGINESCRIPT_HEADER}" = 1 ];
  then
    sed -i "s|#more_set_headers \"X-Powered-By : EngineScript \| EngineScript\\.com\"|more_set_headers \"X-Powered-By : EngineScript \| EngineScript\\.com\"|g" "/etc/nginx/globals/response-headers.conf"
  else
    echo ""
fi

if [ "${NGINX_SECURE_ADMIN}" = 1 ];
  then
    sed -i "s|#satisfy any|satisfy any|g" "/etc/nginx/admin/admin.localhost.conf"
    sed -i "s|#auth_basic|auth_basic|g" "/etc/nginx/admin/admin.localhost.conf"
    sed -i "s|#allow |allow |g" "/etc/nginx/admin/admin.localhost.conf"
  else
    echo ""
fi

# Nginx Service Check
STATUS="$(systemctl is-active nginx)"
if [ "${STATUS}" = "active" ]; then
  echo "PASSED: Nginx is running."
  echo "NGINX=1" >> /var/log/EngineScript/install-log.txt
else
  echo "FAILED: Nginx not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Nginx Installation Completed
echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Nginx installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
