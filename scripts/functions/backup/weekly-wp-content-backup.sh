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
    echo "Running WP-Content Backup for ${i}"
    cd "/var/www/sites/$i/html"

    # Local WP-Content Backup
    mkdir -p "/home/EngineScript/site-backups/$i/wp-content/weekly/${NOW}"
    tar -zcf "/home/EngineScript/site-backups/$i/wp-content/weekly/${WPCONTENT_FILE}" wp-content

    # Amazon S3 WP-Content Backup
    if [[ "$INSTALL_S3_BACKUP" == "1" ]] && [[ "$S3_BUCKET_NAME" != "PLACEHOLDER" ]] && [[ "$WEEKLY_S3_WPCONTENT_BACKUP" == "1" ]];
        then
        echo "Uploading WP-Content Backup for ${i} to Amazon S3 Bucket"
        /usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/wp-content/weekly/${WPCONTENT_FILE}" "s3://${S3_BUCKET_NAME}/$i/backups/wp-content/weekly/${WPCONTENT_FILE}" --storage-class STANDARD
    fi

      # Remove Old Backups
    find "/home/EngineScript/site-backups/$i/wp-content" -type d,f -mtime +7 | xargs rm -fR
done
