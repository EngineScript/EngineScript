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

# Add X-Cache-Enabled Header Maps for WordPress Site Health (2025-07-25)
if ! grep -q "X-Cache-Enabled Header Maps" /etc/nginx/globals/map-cache.conf; then
    echo "Adding X-Cache-Enabled header maps to map-cache.conf..."
    cat >> /etc/nginx/globals/map-cache.conf << 'EOF'

# X-Cache-Enabled Header Maps for WordPress Site Health
map $upstream_cache_status $header_x_cache_enabled {
  default true;
  BYPASS "";
}

map $server_addr:$remote_addr $is_loopback_request {
  "~^([^:]+):\1$" 1;
  default 0;
}

map $is_loopback_request:$header_x_cache_enabled $loopback_header_x_cache_enabled {
  default "";
  1:true true;
}
EOF
    echo "X-Cache-Enabled header maps added successfully."
fi

# Add X-Cache-Enabled Header to response headers (2025-07-25)
if ! grep -q "X-Cache-Enabled" /etc/nginx/globals/response-headers.conf; then
    echo "Adding X-Cache-Enabled header to response-headers.conf..."
    sed -i '/add_header X-FastCGI-Cache/a\\n# Additional cache header for WordPress Site Health check compatibility\nadd_header X-Cache-Enabled "$loopback_header_x_cache_enabled" always;' /etc/nginx/globals/response-headers.conf
    echo "X-Cache-Enabled header added successfully."
fi

