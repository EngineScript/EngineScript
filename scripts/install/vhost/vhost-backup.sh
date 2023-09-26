#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
PHP_FILE="${NOW}-php.tar.gz";
SSL_FILE="${NOW}-ssl-keys.gz";
UPLOADS_FILE="${NOW}-uploads.tar.gz";
VHOST_FILE="${NOW}-nginx-vhost.conf.gz";
WPCONFIG_FILE="${NOW}-wp-config.php.gz";
WPCONTENT_FILE="${NOW}-wp-content.gz";

for i in "${SITES[@]}"
do
	cd "/var/www/sites/$i/html"

	# Backup database
	wp db export "/home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

	# Compress database file
	gzip -f "/home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE"

	# Backup uploads directory
	#tar -zcf "/home/EngineScript/site-backups/$i/wp-uploads/$UPLOADS_FILE" wp-content/uploads

	# Backup uploads, themes, and plugins
	tar -zcf "/home/EngineScript/site-backups/$i/wp-content/$WPCONTENT_FILE" wp-content

  # Nginx vhost backup
  gzip -cf "/etc/nginx/sites-enabled/$i.conf" > /home/EngineScript/site-backups/$i/nginx/$VHOST_FILE

  # SSL keys backup
  tar -zcf "/home/EngineScript/site-backups/$i/ssl-keys/$SSL_FILE" /etc/nginx/ssl/$i

  # wp-config.php backup
  gzip -cf "/var/www/sites/$i/html/wp-config.php" > /home/EngineScript/site-backups/$i/wp-config/$WPCONFIG_FILE

  # Remove old backups
	find /home/EngineScript/site-backups/$i/database/daily -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/nginx -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/ssl-keys -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/wp-config -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/wp-content -type f -mtime +15 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/wp-uploads -type f -mtime +15  | xargs rm -fR
done
