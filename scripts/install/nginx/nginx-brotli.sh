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



#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
cd /usr/src

# Brotli

# Remove existing ngx_brotli directory if it exists
if [ -d "/usr/src/ngx_brotli" ]; then
  rm -rf /usr/src/ngx_brotli
fi

# Git Clone
git clone --recurse-submodules --remote-submodules https://github.com/google/ngx_brotli.git /usr/src/ngx_brotli
cd /usr/src/ngx_brotli
git submodule update --init

# Compile Dependencies
cd /usr/src/ngx_brotli/deps/brotli
mkdir out && cd out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release --target brotlienc

# Return to /usr/src
cd /usr/src
