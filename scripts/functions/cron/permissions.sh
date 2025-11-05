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
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

for i in "${SITES[@]}"
do
	cd "/var/www/sites/$i/html"

	# Directories
	find . -type d -print0 | sudo xargs -0 chmod 0755

	# Files
	find . -type f -print0 | sudo xargs -0 chmod 0644

	# wp-config.php
	chmod 600 wp-config.php

	# Ownership
	chown -R www-data:www-data ./*

  # Make wp-cron executable
  chmod +x wp-cron.php
done

# Assign Nginx Permissions
set_nginx_permissions

# Assign PHP Permissions
set_php_permissions

# Ensure correct socket ownership and permissions
chown redis:redis /run/redis/redis-server.sock 2>/dev/null || true
chmod 770 /run/redis/redis-server.sock 2>/dev/null || true

# Convert line endings
dos2unix /usr/local/bin/enginescript/*

# Set directory and file permissions to 755
find /usr/local/bin/enginescript -exec chmod 755 {} \;

# Set ownership
chown -R root:root /usr/local/bin/enginescript

# Make shell scripts executable
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;
