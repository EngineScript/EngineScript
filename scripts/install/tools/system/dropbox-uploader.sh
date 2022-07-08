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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Clone Git
git clone --depth 1 https://github.com/andreafabrizi/Dropbox-Uploader.git -b master /usr/local/bin/dropbox-uploader

chmod +x /usr/local/bin/dropbox-uploader/dropbox_uploader.sh
/usr/local/bin/dropbox-uploader/dropbox_uploader.sh

# Test installation
echo "Now attempting to send a test upload to Dropbox."
echo "We've sent the dropbox_uploader.sh script to your Dropbox folder. If it didn't work, then you did something wrong during setup."

/usr/local/bin/dropbox-uploader/dropbox_uploader.sh -k upload /usr/local/bin/dropbox-uploader/dropbox_uploader.sh .

echo "Check your Dropbox"
