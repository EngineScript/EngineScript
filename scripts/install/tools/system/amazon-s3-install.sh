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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

clear
# Install Amazon AWS Client
cd /usr/src
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo /usr/src/aws/install
aws --version

# Configuration
echo ""
echo ""
echo "Now it's time to configure Amazon S3."
echo "If you haven't already done so, following these guides before continuing"
echo "- User creation: Follow sections 2 and 3: https://deliciousbrains.com/wp-offload-media/doc/amazon-s3-quick-start-guide/#iam-user"
echo "- Bucket creation: Follow https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html"

# Continue?
while true;
  do
    read -p "When finished, enter ${BOLD}y${NORMAL} to continue to the next step: " y
      case "$y" in
        [Yy]* )
          echo "Let's continue";
          sleep 1;
          break
          ;;
        * ) echo "Please answer y";;
      esac
  done
aws configure

# Test Installation
echo "Now attempting to send a test upload to S3."
echo "Check your S3 bucket for an empty file titled test.txt. If it didn't work, then you did something wrong during setup."
touch /usr/src/test.txt
aws s3 cp /usr/src/test.txt "s3://${S3_BUCKET_NAME}" --storage-class STANDARD # Added quotes
echo "Check your S3 bucket"
