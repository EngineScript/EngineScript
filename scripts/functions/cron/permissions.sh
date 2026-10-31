#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

for i in "${SITES[@]}"
do
	if [[ ! -d "/var/www/sites/$i/html" ]]; then
		continue
	fi

	# Ownership, directories, and files
	set_www_data_tree "/var/www/sites/$i/html"

	# wp-config.php
	run_as_www_data chmod 600 "/var/www/sites/$i/html/wp-config.php"

	# Make wp-cron executable
	run_as_www_data chmod +x "/var/www/sites/$i/html/wp-cron.php"
done

# Assign Nginx Permissions
set_nginx_permissions

# Assign PHP Permissions
set_php_permissions

# /home/EngineScript holds credentials and backups: root only
set_enginescript_home_permissions

# Assign Redis Permissions
set_redis_permissions

# /var/log/EngineScript belongs to root, because root writes logs there
set_enginescript_log_permissions

# Convert line endings
dos2unix /usr/local/bin/enginescript/*

# Set directory and file permissions to 755
find /usr/local/bin/enginescript -exec chmod 755 {} \;

# Set ownership
chown -R root:root /usr/local/bin/enginescript

# Make shell scripts executable
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;
