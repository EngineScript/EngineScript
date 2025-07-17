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

echo "🔧 Fixing EngineScript API Security Log Permissions..."

# Ensure the EngineScript log directory exists
mkdir -p "/var/log/EngineScript"

# Create the API security log file if it doesn't exist
if [[ ! -f "/var/log/EngineScript/enginescript-api-security.log" ]]; then
    echo "📝 Creating API security log file..."
    touch "/var/log/EngineScript/enginescript-api-security.log"
    echo "✅ API security log file created"
else
    echo "✅ API security log file already exists"
fi

# Set proper permissions
echo "🔐 Setting proper permissions..."
chown www-data:www-data "/var/log/EngineScript/enginescript-api-security.log"
chmod 644 "/var/log/EngineScript/enginescript-api-security.log"

# Verify the permissions
echo "🔍 Verifying permissions..."
ls -la "/var/log/EngineScript/enginescript-api-security.log"

# Remove any old log file in the wrong location
if [[ -f "/var/log/enginescript-api-security.log" ]]; then
    echo "🗑️ Removing old log file from incorrect location..."
    rm -f "/var/log/enginescript-api-security.log"
    echo "✅ Old log file removed"
fi

# Ensure MariaDB service always restarts on failure
if grep -q '^Restart=on-abnormal' /lib/systemd/system/mariadb.service; then
  sed -i 's/^Restart=on-abnormal/Restart=always/' /lib/systemd/system/mariadb.service
  systemctl daemon-reload
fi

echo "✅ EngineScript API Security Log permissions fixed successfully!"
echo "The API should now be able to write to the security log without permission errors."
