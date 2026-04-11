#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# WPScan
command -v gem >/dev/null 2>&1 || { echo "Error: RubyGems (gem) is not installed or not in PATH. Please install Ruby/RubyGems before installing WPScan." >&2; exit 1; }

print_install_banner "WPScan"
# Always download the latest version of WPScan. Never source a specific version
# No need for more verbose error messaging
gem install wpscan || { echo "Error: Failed to install WPScan via gem. For troubleshooting, rerun with 'gem install wpscan --verbose' and consult the official RubyGems or WPScan documentation." >&2; exit 1; }
