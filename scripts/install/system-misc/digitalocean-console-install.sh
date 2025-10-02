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

# Check if DigitalOcean Remote Console installation is enabled
if [[ "${INSTALL_DIGITALOCEAN_REMOTE_CONSOLE}" != "1" ]]; then
    echo "DigitalOcean Remote Console installation is disabled in configuration."
    echo "Skipping installation..."
    exit 0
fi

echo "============================================================="
echo "Installing DigitalOcean Droplet Agent for Remote Console"
echo "============================================================="
echo ""

# Download and execute DigitalOcean's official installation script
echo "Downloading and installing DigitalOcean Droplet Agent..."
if wget -qO- https://repos-droplet.digitalocean.com/install.sh | bash; then
    echo "✅ DigitalOcean Droplet Agent installed successfully"
    echo ""
    echo "Remote Console access is now enabled in your DigitalOcean control panel."
    echo ""
else
    echo "❌ Failed to install DigitalOcean Droplet Agent"
    echo "This is not critical if you are not using DigitalOcean."
    echo ""
    exit 1
fi

echo "============================================================="
echo "DigitalOcean Remote Console Installation Complete"
echo "============================================================="
echo ""
