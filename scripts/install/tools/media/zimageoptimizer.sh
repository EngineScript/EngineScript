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

# Install zImageOptimizer
git_clone_fresh "https://github.com/zevilz/zImageOptimizer.git" "/usr/local/bin/zimageoptimizer" --depth 1 -b master
find "/usr/local/bin/zimageoptimizer" -exec chmod 755 {} +

# Return to /usr/src
return_to_src
