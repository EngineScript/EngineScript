#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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

# Update System Software and Tools

# Update Adminer
if [ "${INSTALL_ADMINER}" = 1 ];
  then
    echo "Updating Adminer"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh
  else
    echo "Skipping Adminer update"
fi

# Update liburing
/usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh

# Update MYSQLTuner
/usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

# Update PHP Malware Finder
/usr/local/bin/enginescript/scripts/install/tools/security/php-malware-finder.sh

# Update phpMyAdmin
if [ "${INSTALL_PHPMYADMIN}" = 1 ];
  then
    echo "Updating phpMyAdmin"
    /usr/local/bin/enginescript/scripts/install/tools/security/phpmyadmin-update.sh
  else
    echo "Skipping phpMyAdmin update"
fi

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
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "  - Adminer (if enabled)"
echo "  - liburing"
echo "  - MYSQLTuner"
echo "  - PHP Malware Finder"
echo "  - phpMyAdmin (if enabled)"
echo "  - WP-CLI"
echo "    - WP-CLI Packages"
echo "  - WP-Scan"
echo "  - zImageOptimizer"
echo "  - zlib"
echo ""
echo "============================================================="
echo ""
