#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# EngineScript Update
/usr/local/bin/enginescript/scripts/update/enginescript-update.sh

# Update System Software and Tools
# Update Adminer
/usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh

# Update libdeflate
/usr/local/bin/enginescript/scripts/install/libdeflate/libdeflate-install.sh

# Update MYSQLTuner
/usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

# Update OpCache-GUI
/usr/local/bin/enginescript/scripts/install/tools/php/opcache-gui.sh

# Update PHP Malware Finder
/usr/local/bin/enginescript/scripts/install/tools/security/php-malware-finder.sh

# Update Python
/usr/local/bin/enginescript/scripts/update/python-update.sh

# Update WP-CLI
echo "y" | wp cli update --stable --allow-root
echo "y" | wp package update --allow-root

# Update WP-Scan
gem update wpscan

# Update zImageOptimizer
/usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh

# Update Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh

# Cleanup
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "    - EngineScript"
echo "    - Adminer"
echo "    - libdeflate"
echo "    - MYSQLTuner"
echo "    - OpCache-GUI"
echo "    - PHP Malware Finder"
echo "    - Python Packages"
echo "    - WP-CLI"
echo "      - WP-CLI Packages"
echo "    - WP-Scan"
echo "    - zImageOptimizer"
echo "    - zlib"
echo ""
echo "============================================================="
echo ""
echo ""
