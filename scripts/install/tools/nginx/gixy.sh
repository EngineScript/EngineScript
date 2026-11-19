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

# GIXY-NEXT (maintained fork of Gixy)
# https://github.com/MegaManSec/Gixy-Next
# Uses pipx to install in an isolated virtual environment (PEP 668 compliance). It goes to
# /opt/pipx with the command in /usr/local/bin, so every shell and the Server Tools menu find
# it (pipx's default, ~/.local/bin, is not on every shell's PATH). --force installs the latest
# release over an earlier one, so running this again updates it.
# --no-install-recommends: pipx recommends mkdocs, a documentation site generator that brings in
# about 40 packages (numpy, nltk, pytest, tk, and others); Gixy-Next uses none of them.
apt-get install -qy --no-install-recommends pipx || { echo "Error: pipx could not be installed, so Gixy-Next was not installed." >&2; exit 1; }
# pipx writes its progress to stderr, which the install shows as errors, so that output is shown
# only when it fails (Ubuntu 24.04's pipx 1.4 has no --quiet)
PIPX_ERRORS="$(mktemp)"
if ! PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --force gixy-next 2> "${PIPX_ERRORS}"; then
  cat "${PIPX_ERRORS}" >&2
  rm -f "${PIPX_ERRORS}"
  echo "Error: Gixy-Next could not be installed." >&2
  exit 1
fi
rm -f "${PIPX_ERRORS}"

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
