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


#----------------------------------------------------------------------------
# Start Main Script

# Directly remove JSON cache files from the API cache directory.
CACHE_DIR="/var/cache/enginescript/api"

if [[ -d "${CACHE_DIR}" ]]; then
  # Remove cache files safely, suppress errors
  find "${CACHE_DIR}" -maxdepth 1 -type f -name '*.json' -exec rm -f {} \; 2>/dev/null || true
fi
