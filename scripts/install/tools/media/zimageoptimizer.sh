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

# Remove existing zImageOptimizer directory if it exists
if [[ -d "/usr/local/bin/zimageoptimizer" ]]; then
  rm -rf "/usr/local/bin/zimageoptimizer"
fi

# Install zImageOptimizer
git clone --depth 1 "https://github.com/zevilz/zImageOptimizer.git" -b master "/usr/local/bin/zimageoptimizer"
find "/usr/local/bin/zimageoptimizer" -type d,f -exec chmod 755 {} \;

# Return to /usr/src
cd /usr/src
