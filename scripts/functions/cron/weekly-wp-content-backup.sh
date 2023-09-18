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

	# Local WP-Content Backup
	tar -zcf "/home/EngineScript/site-backups/$i/wp-content/$WPCONTENT_FILE" wp-content

	# Amazon S3 WP-Content Backup
	if [ $INSTALL_S3_BACKUP = 1 ] && [ $S3_BUCKET_NAME != PLACEHOLDER ] && [ $WEEKLY_S3_WPCONTENT_BACKUP = 1 ];
	  then
			/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/wp-content/$WPCONTENT_FILE" "s3://$i/backups/wp-content" --storage-class STANDARD
	fi

	# Dropbox WP-Content Backup
	if [ $INSTALL_DROPBOX_BACKUP = 1 ] && [ $WEEKLY_DROPBOX_WPCONTENT_BACKUP = 1 ];
		then
			/usr/local/bin/dropbox-uploader/dropbox_uploader.sh -kqs upload /home/EngineScript/site-backups/$i/wp-content/$WPCONTENT_FILE /$i/backups/wp-content
	fi

  # Remove Old Backups
	find /home/EngineScript/site-backups/$i/wp-content -type f -mtime +7 | xargs rm -fR
done
