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


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
cd /usr/src

# Install pngout

# Try downloading pngout with timeout and fallback URLs
PNGOUT_DOWNLOADED=false
PNGOUT_FILE="/usr/src/pngout-${PNGOUT_VER}-linux.tar.gz"

# Primary URL (updated with working link)
echo "Attempting to download pngout from primary URL..."
if safe_wget "https://www.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz" "$PNGOUT_FILE" 2>/dev/null; then
    echo "Successfully downloaded pngout from primary URL"
    PNGOUT_DOWNLOADED=true
else
    echo "Primary URL failed, trying fallback URL..."
    # Fallback URL (original)
    if safe_wget "https://static.jonof.id.au/files/kenutils/pngout-${PNGOUT_VER}-linux.tar.gz" "$PNGOUT_FILE" 2>/dev/null; then
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
    
    # Install 32-BIT or 64-BIT
    if [[ "${BIT_TYPE}" == 'x86_64' ]]; then
        # 64-bit
        if [[ -f "/usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout" ]]; then
            cp "/usr/src/pngout-${PNGOUT_VER}-linux/amd64/pngout" /bin
            echo "pngout (64-bit) installed successfully"
        else
            echo "Warning: 64-bit pngout binary not found in archive"
        fi
    else
        # 32-bit
        if [[ -f "/usr/src/pngout-${PNGOUT_VER}-linux/i686/pngout" ]]; then
            cp "/usr/src/pngout-${PNGOUT_VER}-linux/i686/pngout" /bin
            echo "pngout (32-bit) installed successfully"
        else
            echo "Warning: 32-bit pngout binary not found in archive"
        fi
    fi
    
    # Clean up
    rm -f "$PNGOUT_FILE"
    rm -rf "/usr/src/pngout-${PNGOUT_VER}-linux"
else
    echo "Continuing installation without pngout..."
fi

# Return to /usr/src
cd /usr/src
