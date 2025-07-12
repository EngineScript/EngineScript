#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript Configuration Updater
# Populates .conf files from main credentials file
#----------------------------------------------------------------------------------
# This script reads values from the main install options file and updates
# the individual .conf files for various EngineScript services
#----------------------------------------------------------------------------------

set -e

# Source configuration
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

echo "Updating EngineScript configuration files..."

# Update Uptime Robot Configuration
update_uptimerobot_config() {
    local config_file="/etc/enginescript/uptimerobot.conf"
    
    if [[ -f "$config_file" ]]; then
        echo "Updating Uptime Robot configuration..."
        
        # Only update if API key is not PLACEHOLDER
        if [[ "$UPTIMEROBOT_API_KEY" != "PLACEHOLDER" ]] && [[ -n "$UPTIMEROBOT_API_KEY" ]]; then
            # Update configuration - handle both empty and existing values
            sed -i "s|^api_key=.*|api_key=${UPTIMEROBOT_API_KEY}|g" "$config_file"
            
            echo "✓ Uptime Robot configuration updated"
        else
            echo "ℹ Uptime Robot API key is PLACEHOLDER or empty - configuration not updated (optional service)"
        fi
    else
        echo "⚠ Uptime Robot configuration file not found at $config_file"
    fi
}

# Main execution
echo "================================="
echo "EngineScript Configuration Update"
echo "================================="

# Update configurations
update_uptimerobot_config

echo ""
echo "Configuration update completed!"
echo ""

# Log the update
logger "EngineScript: Configuration files updated from main credentials file"
