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

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check if es.sites alias is missing and add it if needed
if ! grep -q "alias es.sites=" /root/.bashrc; then
    echo "Adding missing es.sites alias to /root/.bashrc"
    echo 'alias es.sites="/usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh"' >> /root/.bashrc
fi

# Check for missing credential placeholders and add them if needed
CREDENTIALS_FILE="/home/EngineScript/enginescript-install-options.txt"

if [[ -f "$CREDENTIALS_FILE" ]]; then
    echo "Checking for missing credential placeholders in config file..."
    
    # Check and add File Manager credentials if missing
    if ! grep -q "FILEMANAGER_USERNAME=" "$CREDENTIALS_FILE"; then
        echo "Adding missing File Manager credentials to config file"
        sed -i '/## phpMyAdmin (Recommended) ##/i\\n## File Manager (Recommended) ##\n# Credentials for the Tiny File Manager web interface\n# Allows secure file browsing and management through the admin control panel\nFILEMANAGER_USERNAME="PLACEHOLDER"\nFILEMANAGER_PASSWORD="PLACEHOLDER"\n' "$CREDENTIALS_FILE"
    fi
    
    # Check and add Uptime Robot API key if missing
    if ! grep -q "UPTIMEROBOT_API_KEY=" "$CREDENTIALS_FILE"; then
        echo "Adding missing Uptime Robot API key to config file"
        sed -i '/# DONE/i\\n## Uptime Robot (Optional) ##\n# API key for Uptime Robot website monitoring service\n# Get your API key from: https://uptimerobot.com/dashboard (Settings > API Settings)\nUPTIMEROBOT_API_KEY="PLACEHOLDER"\n' "$CREDENTIALS_FILE"
    fi
    
    echo "Credential placeholder check completed"
else
    echo "Warning: EngineScript credentials file not found at $CREDENTIALS_FILE"
fi
