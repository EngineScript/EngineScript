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

echo ""
echo "============================================="
echo "           Ubuntu Pro Setup"
echo "============================================="
echo ""

# Check if Ubuntu Pro token is configured
if [[ "${UBUNTU_PRO_TOKEN}" != "PLACEHOLDER" && -n "${UBUNTU_PRO_TOKEN}" ]]; then
    echo "Ubuntu Pro token found. Enabling Ubuntu Pro services..."
    
    # Attach Ubuntu Pro subscription
    if pro attach "${UBUNTU_PRO_TOKEN}"; then
        echo "✅ Ubuntu Pro subscription successfully activated"
        
        # Enable additional security updates
        pro enable esm-infra --assume-yes || echo "ESM Infra already enabled or not available"
        pro enable esm-apps --assume-yes || echo "ESM Apps already enabled or not available"
        
        # Enable FIPS updates only if high security SSL is enabled
        if [[ "${HIGH_SECURITY_SSL}" == "1" ]]; then
            echo "High security SSL enabled. Enabling FIPS compliant cryptographic packages..."
            pro enable fips-updates --assume-yes || echo "FIPS updates already enabled or not available"
        else
            echo "High security SSL not enabled. Skipping FIPS updates (can be enabled manually if needed)."
        fi
        
        # Show status
        echo ""
        echo "Ubuntu Pro Status:"
        pro status --format tabular
        
    else
        echo "❌ Failed to attach Ubuntu Pro subscription"
        echo "Please verify your Ubuntu Pro token is valid"
        exit 1
    fi
    
else
    echo "No Ubuntu Pro token configured (UBUNTU_PRO_TOKEN=PLACEHOLDER)"
    echo "Skipping Ubuntu Pro setup..."
    echo ""
    echo "To enable Ubuntu Pro:"
    echo "1. Get your token from: https://ubuntu.com/pro"
    echo "2. Update UBUNTU_PRO_TOKEN in /home/EngineScript/enginescript-install-options.txt"
    echo "3. Re-run this script"
fi

echo ""
echo "============================================="
echo "       Ubuntu Pro Setup Complete"
echo "============================================="
echo ""