#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript Configuration Updater
# Populates .conf files from main credentials file
#----------------------------------------------------------------------------------
# This script reads values from the main install options file and updates
# the individual .conf files for various EngineScript services
#----------------------------------------------------------------------------------

# Source configuration
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

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

# Write Tiny File Manager's login: the username and a hash of the password, in a file the web
# server (www-data) can read, so it never needs the install options file
update_filemanager_login() {
    local login_dir="/var/lib/enginescript/admin"
    local login_file="${login_dir}/tinyfilemanager-auth.json"
    local temp_file

    # The first version of this file was PHP code (tinyfilemanager-auth.php); the login is data now
    rm -f "${login_dir}/tinyfilemanager-auth.php"

    if [[ -z "$FILEMANAGER_USERNAME" || "$FILEMANAGER_USERNAME" == "PLACEHOLDER" \
        || -z "$FILEMANAGER_PASSWORD" || "$FILEMANAGER_PASSWORD" == "PLACEHOLDER" ]]; then
        echo "ℹ File Manager username or password is PLACEHOLDER or empty - login not written"
        rm -f "$login_file"
        return 0
    fi

    echo "Updating File Manager login..."
    mkdir -p "$login_dir" && chown root:www-data "$login_dir" && chmod 750 "$login_dir" || return 1
    temp_file="$(mktemp "${login_dir}/.tinyfilemanager-auth.XXXXXX")" || return 1

    # The password reaches PHP on standard input, so it never appears in a process listing
    # shellcheck disable=SC2016 # PHP code: its $ variables are PHP's, not the shell's
    if printf '%s' "$FILEMANAGER_PASSWORD" | FM_USERNAME="$FILEMANAGER_USERNAME" php -r '
        $login = [
            "username" => (string) getenv("FM_USERNAME"),
            "password_hash" => password_hash((string) stream_get_contents(STDIN), PASSWORD_DEFAULT),
        ];
        echo json_encode($login, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES), "\n";
    ' > "$temp_file" && chown root:www-data "$temp_file" && chmod 640 "$temp_file" && mv -f "$temp_file" "$login_file"; then
        echo "✓ File Manager login updated"
    else
        rm -f "$temp_file"
        echo "Error: Failed to write the File Manager login to $login_file" >&2
        return 1
    fi
}

# Main execution
echo "================================="
echo "EngineScript Configuration Update"
echo "================================="

# Update configurations
CONFIG_FAILED=0
update_uptimerobot_config
update_filemanager_login || CONFIG_FAILED=1

echo ""
echo "Configuration update completed!"
echo ""

# Log the update
logger "EngineScript: Configuration files updated from main credentials file"

exit "$CONFIG_FAILED"
