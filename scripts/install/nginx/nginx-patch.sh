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

# These patches will change based on release. Don't assume they will work with a release other than the version they are intended for.

# Patch Nginx. --forward --batch: never ask a question (patch would read the answer from the
# terminal); a patch that does not apply fails instead, and the build stops.
cd "/usr/src/nginx-${NGINX_VER}" || { echo "Error: Failed to change to /usr/src/nginx-${NGINX_VER}" >&2; exit 1; }
if ! patch -p1 --forward --batch < /usr/local/bin/enginescript/patches/nginx/nginx_dyn_tls.patch; then
  echo "Error: nginx_dyn_tls.patch does not apply to Nginx ${NGINX_VER}; the patch needs updating for this version." >&2
  exit 1
fi
