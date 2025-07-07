#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript File Manager Configuration Notice
#----------------------------------------------------------------------------------
# File Manager now uses native TinyFileManager configuration
#----------------------------------------------------------------------------------

echo "========================================"
echo "File Manager Configuration Notice"
echo "========================================"
echo ""
echo "EngineScript now uses the native TinyFileManager configuration system."
echo ""
echo "To change file manager credentials:"
echo "1. Edit: /var/www/admin/enginescript/tinyfilemanager/config.php"
echo "2. Modify the \$auth_users array with your desired username/password"
echo "3. Use password_hash() to generate secure password hashes"
echo ""
echo "Example:"
echo "  \$auth_users = array("
echo "    'yourusername' => '\$2y\$10\$...' // Use password_hash('yourpassword', PASSWORD_DEFAULT)"
echo "  );"
echo ""
echo "Default credentials: admin/admin"
echo "Location: /enginescript/tinyfilemanager/tinyfilemanager.php"
echo ""
read -p "Enter new password (leave blank to generate): " NEW_PASSWORD

if [[ -z "$NEW_PASSWORD" ]]; then
    NEW_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 12)
    echo "Generated password: $NEW_PASSWORD"
fi

# Update main credentials file
sed -i "s|FILEMANAGER_USERNAME=\".*\"|FILEMANAGER_USERNAME=\"${NEW_USERNAME}\"|g" "$CREDENTIALS_FILE"
sed -i "s|FILEMANAGER_PASSWORD=\".*\"|FILEMANAGER_PASSWORD=\"${NEW_PASSWORD}\"|g" "$CREDENTIALS_FILE"

# Update configuration file using the shared updater
echo "Updating configuration files..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

echo ""
echo "============================================="
echo "File Manager Credentials Updated Successfully!"
echo "Username: $NEW_USERNAME"
echo "Password: $NEW_PASSWORD"
echo "============================================="
echo "IMPORTANT: Save these credentials securely!"
echo ""

# Log the password reset
logger "EngineScript: File manager credentials reset by $(whoami)"

echo "Password reset completed."
