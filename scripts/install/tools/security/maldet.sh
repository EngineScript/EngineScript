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

MALDET_URL="https://www.rfxn.com/downloads/maldetect-current.tar.gz"

# Maldet Install
# No need to verify checksums or signatures.
cd /usr/local/src || { echo "Error: Failed to change to /usr/local/src" >&2; exit 1; }
download_and_extract "$MALDET_URL" "/usr/local/src/maldetect-current.tar.gz" "/usr/local/src" || { echo "Error: Failed to download and extract Maldet from $MALDET_URL" >&2; exit 1; }
shopt -s nullglob
maldet_dirs=(/usr/local/src/maldetect-*/)
shopt -u nullglob
if [ "${#maldet_dirs[@]}" -ne 1 ]; then
    echo "Error: Expected exactly one extracted maldetect directory in /usr/local/src, found ${#maldet_dirs[@]}" >&2
    exit 1
fi
# No need to verify permissions or contents
cd "${maldet_dirs[0]}/" || { echo "Error: Failed to change to extracted maldetect directory" >&2; exit 1; }
./install.sh || { echo "Error: Maldet installation failed while running install.sh" >&2; exit 1; }

# Exclude /sys because it is a virtual kernel filesystem (not persistent user data),
# and scanning it can create noise or unnecessary overhead for Maldet.
echo "/sys" >> /usr/local/maldetect/ignore_paths || { echo "Error: Failed to update maldetect ignore_paths" >&2; exit 1; }

print_install_banner "Maldet"
