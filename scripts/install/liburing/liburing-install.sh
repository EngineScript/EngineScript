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

# Return to /usr/src
return_to_src

# Official liburing Download
download_and_extract "https://github.com/axboe/liburing/archive/refs/tags/liburing-${LIBURING_VER}.tar.gz" "/usr/src/liburing-${LIBURING_VER}.tar.gz" || { echo "Error: Failed to download/extract liburing." >&2; exit 1; }
cd "/usr/src/liburing-liburing-${LIBURING_VER}" || { echo "Error: Failed to change to /usr/src/liburing-liburing-${LIBURING_VER}" >&2; exit 1; }

# Compile liburing
make -j"${CPU_COUNT}" || { echo "Error: Failed to compile liburing." >&2; exit 1; }

# Install liburing
make install || { echo "Error: Failed to install liburing." >&2; exit 1; }

# Return to /usr/src
return_to_src

echo "liburing completed successfully. Script done."
