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

# Admin Control Panel Configuration Migration
# Migrate NGINX_USERNAME/NGINX_PASSWORD to ADMIN_CONTROL_PANEL_USERNAME/ADMIN_CONTROL_PANEL_PASSWORD
# Remove NGINX_SECURE_ADMIN variable as admin panel is now always secured

CONFIG_FILE="/home/EngineScript/enginescript-install-options.txt"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Updating admin control panel configuration..."
    
    # Migrate NGINX_USERNAME to ADMIN_CONTROL_PANEL_USERNAME
    if grep -q "^NGINX_USERNAME=" "$CONFIG_FILE"; then
        # Get the current value
        NGINX_USERNAME_VALUE=$(grep "^NGINX_USERNAME=" "$CONFIG_FILE" | cut -d'=' -f2)
        
        # Add the new variable if it doesn't exist
        if ! grep -q "^ADMIN_CONTROL_PANEL_USERNAME=" "$CONFIG_FILE"; then
            sed -i "s/^NGINX_USERNAME=.*/ADMIN_CONTROL_PANEL_USERNAME=$NGINX_USERNAME_VALUE/" "$CONFIG_FILE"
        fi
        
        # Remove the old variable if the new one exists
        if grep -q "^ADMIN_CONTROL_PANEL_USERNAME=" "$CONFIG_FILE"; then
            sed -i '/^NGINX_USERNAME=/d' "$CONFIG_FILE"
        fi
    fi
    
    # Migrate NGINX_PASSWORD to ADMIN_CONTROL_PANEL_PASSWORD
    if grep -q "^NGINX_PASSWORD=" "$CONFIG_FILE"; then
        # Get the current value
        NGINX_PASSWORD_VALUE=$(grep "^NGINX_PASSWORD=" "$CONFIG_FILE" | cut -d'=' -f2)
        
        # Add the new variable if it doesn't exist
        if ! grep -q "^ADMIN_CONTROL_PANEL_PASSWORD=" "$CONFIG_FILE"; then
            sed -i "s/^NGINX_PASSWORD=.*/ADMIN_CONTROL_PANEL_PASSWORD=$NGINX_PASSWORD_VALUE/" "$CONFIG_FILE"
        fi
        
        # Remove the old variable if the new one exists
        if grep -q "^ADMIN_CONTROL_PANEL_PASSWORD=" "$CONFIG_FILE"; then
            sed -i '/^NGINX_PASSWORD=/d' "$CONFIG_FILE"
        fi
    fi
    
    # Remove NGINX_SECURE_ADMIN variable (admin panel is now always secured)
    if grep -q "^NGINX_SECURE_ADMIN=" "$CONFIG_FILE"; then
        sed -i '/^NGINX_SECURE_ADMIN=/d' "$CONFIG_FILE"
        echo "Removed NGINX_SECURE_ADMIN variable - admin panel is now always secured"
    fi
    
    # Update configuration section headers
    if grep -q "## Nginx Password Protection" "$CONFIG_FILE"; then
        sed -i 's/## Nginx Password Protection (Recommended) ##/## Admin Control Panel Login (Required) ##/' "$CONFIG_FILE"
        sed -i 's/# This adds a second layer of security to the Admin Control Panel on the server. This control panel can be accessed via your IP or admin.DOMAIN.TLD./# These credentials secure access to the Admin Control Panel on the server. This control panel can be accessed via your IP or admin.DOMAIN.TLD./' "$CONFIG_FILE"
        sed -i 's/# Requires NGINX_SECURE_ADMIN=1 be set in the options towards the top of this file./# All admin tools including phpMyAdmin, file manager, and server management require these credentials./' "$CONFIG_FILE"
    fi
    
    echo "Admin control panel configuration migration completed"
fi

