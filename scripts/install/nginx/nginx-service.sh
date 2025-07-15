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

#Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Nginx Service

# Stop Nginx service before replacing binary to avoid "Text file busy" error
if systemctl is-active --quiet nginx; then
    echo "Stopping Nginx service for binary replacement..."
    systemctl stop nginx
fi

# Remove old Nginx service file and copy the new one
rm -rf /usr/lib/systemd/system/nginx.service
cp -rf /usr/local/bin/enginescript/config/etc/systemd/system/nginx.service /etc/systemd/system/nginx.service
chmod 644 /etc/systemd/system/nginx.service

# Reload systemd and enable nginx
systemctl daemon-reload
systemctl enable nginx

# Verify nginx configuration before starting
echo "Testing nginx configuration..."
if ! /usr/sbin/nginx -t; then
    echo "ERROR: Nginx configuration test failed!"
    echo "Please check the configuration and fix any issues before starting nginx."
    exit 1
fi

# Start nginx service
echo "Starting nginx service..."
systemctl start nginx

# Verify nginx is running
if systemctl is-active --quiet nginx; then
    echo "PASSED: Nginx is running."
else
    echo "ERROR: Failed to start nginx service."
    systemctl status nginx
    exit 1
fi
