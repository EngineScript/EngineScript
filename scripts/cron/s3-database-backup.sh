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

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

for i in "${SITES[@]}"
do
	cd "$ROOT/$i/html"

	# Send to S3
  # If you plan on sending backups to S3, you must also install and configure the AWS CLI tools.
	/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/$DATABASE_FILE.gz" "s3://$i/backups/" --storage-class REDUCED_REDUNDANCY
	/usr/local/bin/aws s3 cp "/home/EngineScript/site-backups/$i/$UPLOADS_FILE" "s3://$i/backups/" --storage-class REDUCED_REDUNDANCY
done
