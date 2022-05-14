#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

NOW=$(date +%m-%d-%Y-%H%M)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
SSL_FILE="${NOW}-ssl-keys.gz";
UPLOADS_FILE="${NOW}-uploads.tar.gz";
WPCONFIG_FILE="${NOW}-wp-config.gz";

for i in "${SITES[@]}"
do
	cd "$ROOT/$i/html"

	# Backup database
	/usr/local/bin/wp db export "/home/EngineScript/site-backups/$i/wp-database/$DATABASE_FILE" --add-drop-table --allow-root

	# Compress database file
	gzip -f "/home/EngineScript/site-backups/$i/wp-database/$DATABASE_FILE"

	# Backup uploads directory
	tar -zcf "/home/EngineScript/site-backups/$i/wp-uploads/$UPLOADS_FILE" wp-content/uploads

  # Nginx vhost backup
  gzip -cf "/etc/nginx/sites-enabled/$i.conf" > /home/EngineScript/site-backups/$i/nginx/$NGINX_FILE

  # SSL keys backup
  tar -zcf "/home/EngineScript/site-backups/$i/ssl-keys/$SSL_FILE" /etc/nginx/ssl/$i

  # wp-config.php backup
  gzip -cf "/var/www/sites/$i/html/wp-config.php" > /home/EngineScript/site-backups/$i/wp-config/$WPCONFIG_FILE

  # Remove old backups
  find /home/EngineScript/site-backups/$i/nginx -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/ssl-keys -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/wp-config -type f -mtime +7 | xargs rm -fR
	find /home/EngineScript/site-backups/$i/wp-database -type f -mtime +7 | xargs rm -fR
  find /home/EngineScript/site-backups/$i/wp-uploads -type f -mtime +7  | xargs rm -fR
done
