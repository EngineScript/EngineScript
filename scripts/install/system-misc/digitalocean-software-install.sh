#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

source /etc/enginescript/install-state.conf
if [[ "${DO_CONSOLE}" = 1 ]]; then
    echo "DO_CONSOLE script has already run"
    exit 0
fi

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

# Check if DigitalOcean Metrics Agent installation is enabled
if [[ "${INSTALL_DIGITALOCEAN_METRICS_AGENT}" == "1" ]]; then
    echo "============================================================="
    echo "Installing DigitalOcean Metrics Agent"
    echo "============================================================="
    echo ""
    
    # Download and execute DigitalOcean's official metrics agent installation script
    echo "Downloading and installing DigitalOcean Metrics Agent..."
    if curl -sSL https://repos.insights.digitalocean.com/install.sh | sudo bash; then
        echo "✅ DigitalOcean Metrics Agent installed successfully"
        echo ""
        echo "Enhanced server metrics are now available in your DigitalOcean control panel."
        echo ""
    else
        echo "❌ Failed to install DigitalOcean Metrics Agent"
        echo "This is not critical and does not affect server functionality."
        echo ""
    fi
    
    echo "============================================================="
    echo "DigitalOcean Metrics Agent Installation Complete"
    echo "============================================================="
    echo ""
else
    echo "DigitalOcean Metrics Agent installation is disabled in configuration."
    echo "Skipping metrics agent installation..."
    echo ""
fi

# Mark the installation as complete
echo "DO_CONSOLE=1" >> /etc/enginescript/install-state.conf
