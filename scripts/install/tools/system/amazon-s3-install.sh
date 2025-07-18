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

# Source shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


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
echo ""
echo "When finished, you can continue to the next step."
if prompt_yes_no "Are you ready to continue with AWS configuration?" "y" 300; then
    echo "Let's continue with AWS configuration..."
    sleep 1
    
    # Run AWS configure with error handling
    echo ""
    echo "Starting AWS CLI configuration..."
    echo "You will be prompted for:"
    echo "- AWS Access Key ID"
    echo "- AWS Secret Access Key" 
    echo "- Default region name (e.g., us-east-1)"
    echo "- Default output format (json recommended)"
    echo ""
    
    if ! aws configure; then
        echo ""
        echo "AWS configuration failed or was cancelled."
        echo "You can run 'aws configure' manually later if needed."
        echo "Exiting installation script."
        exit 1
    fi
    
    echo ""
    echo "AWS configuration completed successfully."
else
    echo ""
    echo "AWS configuration cancelled by user."
    echo "You can run this script again later or configure AWS manually with 'aws configure'."
    echo "Exiting installation script."
    exit 0
fi

# Test Installation
echo "Now attempting to send a test upload to S3."
echo "Check your S3 bucket for an empty file titled test.txt. If it didn't work, then you did something wrong during setup."
touch /usr/src/test.txt
aws s3 cp /usr/src/test.txt "s3://${S3_BUCKET_NAME}" --storage-class STANDARD # Added quotes
echo "Check your S3 bucket"
