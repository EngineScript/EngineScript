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

# Install pngout

# Try downloading pngout with timeout and fallback URLs
PNGOUT_DOWNLOADED=false
PNGOUT_FILE="/usr/src/pngout-${PNGOUT_VER}-linux.tar.gz"

# Primary URL (updated with working link)
echo "Attempting to download pngout from primary URL..."
if download_file "https://www.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz" "$PNGOUT_FILE" 2>/dev/null; then
    echo "Successfully downloaded pngout from primary URL"
    PNGOUT_DOWNLOADED=true
else
    echo "Primary URL failed, trying fallback URL..."
    # Fallback URL (original)
    if download_file "https://static.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz" "$PNGOUT_FILE" 2>/dev/null; then
        echo "Successfully downloaded pngout from fallback URL"
        PNGOUT_DOWNLOADED=true
    else
        echo "Warning: Failed to download pngout from both URLs. Skipping pngout installation."
        PNGOUT_DOWNLOADED=false
    fi
fi

# Only proceed with installation if download was successful
if [[ "$PNGOUT_DOWNLOADED" == "true" ]]; then
    echo "Extracting and installing pngout..."
    tar -xzf "$PNGOUT_FILE"
    
    # 64-bit only: setup requires x86_64
    if [[ -f "/usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout" ]]; then
        cp "/usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout" /bin
        echo "pngout installed successfully"
    else
        echo "Warning: 64-bit pngout binary not found in archive"
    fi
    
    # Clean up
    rm -f "$PNGOUT_FILE"
    rm -rf "/usr/src/pngout-${PNGOUT_VER}-linux"
else
    echo "Continuing installation without pngout..."
fi

# Return to /usr/src
return_to_src
