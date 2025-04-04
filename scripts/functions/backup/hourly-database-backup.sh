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

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
FULLWPFILES="${NOW}-wordpress-files.gz";
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

	# Local Database Backup
  	mkdir -p /home/EngineScript/site-backups/$i/database/hourly/${NOW}
  	wp db export "/home/EngineScript/site-backups/$i/database/hourly/${NOW}/$DATABASE_FILE" --add-drop-table --allow-root

	# Compress Database
  	gzip -f "/home/EngineScript/site-backups/$i/database/hourly/${NOW}/$DATABASE_FILE"

	# Amazon S3 Database Backup
	if [ $INSTALL_S3_BACKUP = 1 ] && [ $S3_BUCKET_NAME != PLACEHOLDER ] && [ $HOURLY_S3_DATABASE_BACKUP = 1 ];
		then
		/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/database/hourly/${NOW}/$DATABASE_FILE.gz" "s3://${S3_BUCKET_NAME}/$i/backups/database/hourly/${NOW}/$DATABASE_FILE.gz" --storage-class STANDARD
	fi

	# Remove Old Backups
	find /home/EngineScript/site-backups/$i/database/hourly -type d,f -mtime +1 | xargs rm -fR

done
