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

# Return to /usr/src
return_to_src

# Brotli

# Clone fresh ngx_brotli
git_clone_fresh "https://github.com/google/ngx_brotli.git" "/usr/src/ngx_brotli" --recurse-submodules --remote-submodules \
  || { echo "Error: Failed to clone ngx_brotli." >&2; exit 1; }
cd /usr/src/ngx_brotli || { echo "Error: Failed to change to /usr/src/ngx_brotli" >&2; exit 1; }
git submodule update --init || { echo "Error: Failed to fetch the Brotli library for ngx_brotli." >&2; exit 1; }

# Compile Dependencies
# CPU target: see get_x86_64_level in enginescript-common.sh
X86_64_LEVEL="$(get_x86_64_level)"
mkdir -p /usr/src/ngx_brotli/deps/brotli/out
cd /usr/src/ngx_brotli/deps/brotli/out || { echo "Error: Failed to change to /usr/src/ngx_brotli/deps/brotli/out" >&2; exit 1; }
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=${X86_64_LEVEL} -mtune=generic -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed .. \
  || { echo "Error: Failed to configure the Brotli library." >&2; exit 1; }
cmake --build . --config Release --target brotlienc || { echo "Error: Failed to compile the Brotli library." >&2; exit 1; }

# Return to /usr/src
return_to_src
