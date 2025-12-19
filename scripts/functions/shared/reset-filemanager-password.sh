#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript File Manager Configuration Notice
#----------------------------------------------------------------------------------
# File Manager now uses native TinyFileManager with dynamic credentials
#----------------------------------------------------------------------------------

echo "========================================"
echo "File Manager Configuration Notice"
echo "========================================"
echo ""
echo "EngineScript TinyFileManager now uses dynamic authentication."
echo "Credentials are automatically loaded from your main EngineScript configuration."
echo ""
echo "To change file manager credentials:"
echo "1. Run: es.config"
echo "2. Update FILEMANAGER_USERNAME and FILEMANAGER_PASSWORD"
echo "3. Restart web server: sudo systemctl reload nginx"
echo ""
echo "Current configuration:"
echo "  - Credentials file: /home/EngineScript/enginescript-install-options.txt"
echo "  - Configuration: /var/www/admin/tools/tinyfilemanager/config.php"
echo "  - Access URL: /tinyfilemanager/tinyfilemanager.php"
echo ""
echo "Note: Passwords are automatically hashed using PHP password_hash() function."
echo ""
