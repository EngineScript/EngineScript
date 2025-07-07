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

# Update File Manager Configuration
update_filemanager_config() {
    local config_file="/etc/enginescript/filemanager.conf"
    
    if [[ -f "$config_file" ]]; then
        echo "Updating File Manager configuration..."
        echo "  - Config file: $config_file"
        echo "  - Username: $FILEMANAGER_USERNAME"
        echo "  - Password: [length: ${#FILEMANAGER_PASSWORD}]"
        
        # Only update if credentials are not PLACEHOLDER
        if [[ "$FILEMANAGER_USERNAME" != "PLACEHOLDER" ]] && [[ "$FILEMANAGER_PASSWORD" != "PLACEHOLDER" ]]; then
            # Generate password hash
            local password_hash
            password_hash=$(php -r "echo password_hash('${FILEMANAGER_PASSWORD}', PASSWORD_DEFAULT);")
            
            # Update configuration - handle both empty and existing values
            sed -i "s|^fm_username=.*|fm_username=${FILEMANAGER_USERNAME}|g" "$config_file"
            sed -i "s|^fm_password=.*|fm_password=${FILEMANAGER_PASSWORD}|g" "$config_file"
            sed -i "s|^fm_password_hash=.*|fm_password_hash=${password_hash}|g" "$config_file"
            
            echo "✓ File Manager configuration updated"
            echo "  - Configuration file populated with user credentials"
        else
            echo "⚠ File Manager credentials still contain PLACEHOLDER values - skipping update"
            echo "  - Run 'es.config' to set FILEMANAGER_USERNAME and FILEMANAGER_PASSWORD"
        fi
    else
        echo "⚠ File Manager configuration file not found at $config_file"
    fi
}

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
update_filemanager_config
update_uptimerobot_config

echo ""
echo "Configuration update completed!"
echo ""

# Log the update
logger "EngineScript: Configuration files updated from main credentials file"
