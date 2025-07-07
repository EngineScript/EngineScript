#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript Configuration Update Alias
#----------------------------------------------------------------------------------
# Simple alias command for updating configuration files
#----------------------------------------------------------------------------------

echo "EngineScript Configuration Update"
echo "================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This command must be run as root (use sudo)" 
   exit 1
fi

# Run the configuration updater
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

echo ""
echo "Use 'es.config' to edit your main credentials file if needed."
