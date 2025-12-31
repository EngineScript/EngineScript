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

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

#----------------------------------------------------------------------------------
# Start Main Script

# Upgrade Scripts will be found below:

#----------------------------------------------------------------------------------
# Migration: Admin Tools Directory Structure (2025-12-31)
# 
# Migrates admin tools from old /var/www/admin/enginescript/ structure
# to new separated structure:
#   - Control Panel: /var/www/admin/control-panel/
#   - Tools: /var/www/admin/tools/
#
# This ensures phpMyAdmin and other tools survive EngineScript updates.
#----------------------------------------------------------------------------------

migrate_admin_tools() {
    local OLD_ADMIN_DIR="/var/www/admin/enginescript"
    local NEW_TOOLS_DIR="/var/www/admin/tools"
    local NEW_PANEL_DIR="/var/www/admin/control-panel"
    local MIGRATION_NEEDED=0

    # Check if old directory structure exists
    if [[ -d "$OLD_ADMIN_DIR" ]]; then
        echo "============================================================="
        echo "Admin Tools Migration: Detected old directory structure"
        echo "============================================================="
        
        # Create new directories
        mkdir -p "$NEW_TOOLS_DIR"
        mkdir -p "$NEW_PANEL_DIR"
        
        # Migrate phpMyAdmin (preserve config!)
        if [[ -d "$OLD_ADMIN_DIR/phpmyadmin" ]]; then
            echo "Migrating phpMyAdmin..."
            if [[ ! -d "$NEW_TOOLS_DIR/phpmyadmin" ]]; then
                mv "$OLD_ADMIN_DIR/phpmyadmin" "$NEW_TOOLS_DIR/phpmyadmin"
                echo "  ✓ phpMyAdmin migrated to $NEW_TOOLS_DIR/phpmyadmin"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ phpMyAdmin already exists in new location, skipping"
            fi
        fi
        
        # Migrate Adminer
        if [[ -d "$OLD_ADMIN_DIR/adminer" ]]; then
            echo "Migrating Adminer..."
            if [[ ! -d "$NEW_TOOLS_DIR/adminer" ]]; then
                mv "$OLD_ADMIN_DIR/adminer" "$NEW_TOOLS_DIR/adminer"
                echo "  ✓ Adminer migrated to $NEW_TOOLS_DIR/adminer"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ Adminer already exists in new location, skipping"
            fi
        fi
        
        # Migrate TinyFileManager (preserve config!)
        if [[ -d "$OLD_ADMIN_DIR/tinyfilemanager" ]]; then
            echo "Migrating TinyFileManager..."
            if [[ ! -d "$NEW_TOOLS_DIR/tinyfilemanager" ]]; then
                mv "$OLD_ADMIN_DIR/tinyfilemanager" "$NEW_TOOLS_DIR/tinyfilemanager"
                echo "  ✓ TinyFileManager migrated to $NEW_TOOLS_DIR/tinyfilemanager"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ TinyFileManager already exists in new location, skipping"
            fi
        fi
        
        # Migrate phpSysInfo
        if [[ -d "$OLD_ADMIN_DIR/phpsysinfo" ]]; then
            echo "Migrating phpSysInfo..."
            if [[ ! -d "$NEW_TOOLS_DIR/phpsysinfo" ]]; then
                mv "$OLD_ADMIN_DIR/phpsysinfo" "$NEW_TOOLS_DIR/phpsysinfo"
                echo "  ✓ phpSysInfo migrated to $NEW_TOOLS_DIR/phpsysinfo"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ phpSysInfo already exists in new location, skipping"
            fi
        fi
        
        # Migrate phpinfo
        if [[ -d "$OLD_ADMIN_DIR/phpinfo" ]]; then
            echo "Migrating phpinfo..."
            if [[ ! -d "$NEW_TOOLS_DIR/phpinfo" ]]; then
                mv "$OLD_ADMIN_DIR/phpinfo" "$NEW_TOOLS_DIR/phpinfo"
                echo "  ✓ phpinfo migrated to $NEW_TOOLS_DIR/phpinfo"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ phpinfo already exists in new location, skipping"
            fi
        fi
        
        # Migrate OpCache-GUI
        if [[ -d "$OLD_ADMIN_DIR/opcache-gui" ]]; then
            echo "Migrating OpCache-GUI..."
            if [[ ! -d "$NEW_TOOLS_DIR/opcache-gui" ]]; then
                mv "$OLD_ADMIN_DIR/opcache-gui" "$NEW_TOOLS_DIR/opcache-gui"
                echo "  ✓ OpCache-GUI migrated to $NEW_TOOLS_DIR/opcache-gui"
                MIGRATION_NEEDED=1
            else
                echo "  ℹ OpCache-GUI already exists in new location, skipping"
            fi
        fi
        
        # Set permissions on migrated tools
        if [[ "$MIGRATION_NEEDED" -eq 1 ]]; then
            echo "Setting permissions on migrated tools..."
            chown -R www-data:www-data "$NEW_TOOLS_DIR"
            find "$NEW_TOOLS_DIR" -type d -exec chmod 755 {} \;
            find "$NEW_TOOLS_DIR" -type f -exec chmod 644 {} \;
            
            echo ""
            echo "============================================================="
            echo "Admin Tools Migration Complete!"
            echo "============================================================="
            echo ""
            echo "Tools are now stored in: $NEW_TOOLS_DIR"
            echo "Control panel is now in: $NEW_PANEL_DIR"
            echo ""
            echo "This separation ensures your tool configurations"
            echo "(especially phpMyAdmin) survive future EngineScript updates."
            echo "============================================================="
            echo ""
        fi
        
        # Clean up old directory if empty
        if [[ -d "$OLD_ADMIN_DIR" ]]; then
            # Check if directory is empty (only contains . and ..)
            if [[ -z "$(ls -A "$OLD_ADMIN_DIR" 2>/dev/null)" ]]; then
                rmdir "$OLD_ADMIN_DIR" 2>/dev/null || true
                echo "Removed empty old admin directory: $OLD_ADMIN_DIR"
            else
                echo "Note: Old admin directory still contains files: $OLD_ADMIN_DIR"
                echo "      Please review and remove manually if no longer needed."
            fi
        fi
    fi
}

# Run migration check
migrate_admin_tools