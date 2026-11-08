#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# Write EngineScript's Nginx configuration, for both the install (nginx-install.sh) and the
# update (nginx-update.sh). The update sets ENGINESCRIPT_SKIP_NGINX_RELOAD=1, so nothing here
# reloads the running Nginx before the update has tested the new configuration. Every step runs;
# the script exits 1 when any of them failed.

FAILED=0

# Create Directories
run_step "Create Nginx Directories" /usr/local/bin/enginescript/scripts/install/nginx/nginx-create-directories.sh || FAILED=1

# Misc Nginx Stuff (copies the configuration and migrates existing vhost files)
run_step "Misc Nginx Stuff" /usr/local/bin/enginescript/scripts/install/nginx/nginx-misc.sh || FAILED=1

# Tune Nginx (also syncs the HTTP/3 directives of nginx.conf and the vhosts with INSTALL_HTTP3)
run_step "Tune Nginx" /usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh || FAILED=1

# Cloudflare
run_step "Cloudflare" /usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare.sh || FAILED=1

# Show the EngineScript header when SHOW_ENGINESCRIPT_HEADER=1 (the copied configuration has it
# commented out)
if [[ "${SHOW_ENGINESCRIPT_HEADER}" == "1" ]]; then
  sed -i "s|#more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|more_set_headers \"X-Powered-By : EngineScript \| EngineScript\.com\"|g" /etc/nginx/globals/response-headers.conf
fi

exit "${FAILED}"
