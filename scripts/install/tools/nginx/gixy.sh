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

# GIXY-NEXT (maintained fork of Gixy)
# https://github.com/MegaManSec/Gixy-Next
# Uses pipx to install in an isolated virtual environment (PEP 668 compliance). It goes to
# /opt/pipx with the command in /usr/local/bin, so every shell and the Server Tools menu find
# it (pipx's default, ~/.local/bin, is not on every shell's PATH). --force installs the latest
# release over an earlier one, so running this again updates it.
apt install -qy pipx
PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --force gixy-next

echo ""
echo ""
echo "============================================================="
echo ""
echo "  ${BOLD}Gixy-Next installed.${NORMAL}"
echo ""
echo "  To run a scan of your Nginx configuration:"
echo "  gixy /etc/nginx/nginx.conf"
echo "  gixy /etc/nginx/sites-enabled/YOURDOMAIN.TLD.conf"
echo "  Example: gixy /etc/nginx/sites-enabled/wordpresstesting.com.conf"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 3
