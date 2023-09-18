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
# Start Main Script

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
WPCONFIG_FILE="${NOW}-wp-config.gz";
WPCONTENT_FILE="${NOW}-wp-content.gz";

for i in "${SITES[@]}"
do
	cd "/var/www/sites/$i/html"

	# Local Database Backup
	/usr/local/src/wp db export "/home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

	# Compress Database
	gzip -f "/home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE"

	# wp-config.php backup
  gzip -cf "/var/www/sites/$i/html/wp-config.php" > /home/EngineScript/site-backups/$i/wp-config/$WPCONFIG_FILE

	# Amazon S3 Database Backup
	if [ $INSTALL_S3_BACKUP = 1 ] && [ $S3_BUCKET_NAME != PLACEHOLDER ] && [ $DAILY_S3_DATABASE_BACKUP = 1 ];
	  then
			/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE.gz" "s3://$i/backups/database/daily" --storage-class STANDARD
			/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/database/daily/$WPCONFIG_FILE" "s3://$i/backups/database/daily" --storage-class STANDARD
	fi

	# Dropbox Database Backup
	if [ $INSTALL_DROPBOX_BACKUP = 1 ] && [ $DAILY_DROPBOX_DATABASE_BACKUP = 1 ];
		then
			/usr/local/bin/dropbox-uploader/dropbox_uploader.sh -kqs upload /home/EngineScript/site-backups/$i/database/daily/$DATABASE_FILE /$i/backups/database/daily
			/usr/local/bin/dropbox-uploader/dropbox_uploader.sh -kqs upload /home/EngineScript/site-backups/$i/database/daily/$WPCONFIG_FILE /$i/backups/database/daily
	fi

  # Remove Old Backups
	find /home/EngineScript/site-backups/$i/database/daily -type f -mtime +7 | xargs rm -fR
	find /home/EngineScript/site-backups/$i/wp-config -type f -mtime +7 | xargs rm -fR
done
