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

# Download, build, and install Nginx (nginx-build.sh is shared with the update)
/usr/local/bin/enginescript/scripts/install/nginx/nginx-build.sh || die "Building Nginx failed. Stopping the Nginx install; see /var/log/EngineScript/install-error-log.log."

# Write the configuration (nginx-configure.sh is shared with the update)
/usr/local/bin/enginescript/scripts/install/nginx/nginx-configure.sh || die "Writing the Nginx configuration failed. Stopping the Nginx install; see /var/log/EngineScript/install-error-log.log."

# Backup Nginx
run_step "Backup Nginx" /usr/local/bin/enginescript/scripts/functions/backup/nginx-backup.sh

# SSL
run_step "SSL" /usr/local/bin/enginescript/scripts/install/nginx/nginx-ssl.sh

# Assign Admin Password
run_step "Admin Password" /usr/local/bin/enginescript/scripts/install/nginx/nginx-admin-password.sh

# Assign Permissions BEFORE nginx tries to start
set_nginx_permissions

# Install Nginx Service
run_step "Nginx Service" /usr/local/bin/enginescript/scripts/install/nginx/nginx-service.sh

# Nginx Service Check
verify_service_running "nginx" "Nginx"

# What this Nginx was built from, so the automatic updates know the server is current
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh || die "Failed to source enginescript-auto-update.sh."
record_nginx_build_fingerprint

# Nginx Installation Completed
print_install_banner "Nginx"

echo "Nginx completed successfully. Script done."
