#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

echo "ClamAV is running. The scan may take a long time; stand by for results."
clamscan --infected --recursive --leave-temps --scan-archive=no --exclude-dir="^/sys" --exclude-dir="^/tmp" --exclude-dir="^/root/.wp-cli/packages/vendor/pantheon-systems/" --exclude-dir="^/usr/local/maldetect" --exclude-dir="^var/lib/clamav" --exclude-dir="^/usr/local/src" /

# Ask user to acknowledge that the scan has completed before moving on
pause
