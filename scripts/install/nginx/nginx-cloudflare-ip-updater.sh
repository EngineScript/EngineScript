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

# A bash script to download the latest list of Cloudflare IP addresses
# ranges to be used with Nginx for the purpose of displaying a
# visitor's real IP address
#
# Author: Eric Mathison - https://ericmathison.com
# Modified: EngineScript - https://enginescript.com
#

# Nginx config file that contains Cloudflare's IP ranges
CLOUDFLARE_NGINX_CONFIG="/etc/nginx/globals/cloudflare.conf"

# Download and check the ranges (cf_ip_ranges: every line must be an address range)
if ! IPV4_RANGES="$(cf_ip_ranges v4)" || ! IPV6_RANGES="$(cf_ip_ranges v6)"; then
	echo "FAILED. Reason: Cloudflare's IP ranges could not be downloaded or are not valid; ${CLOUDFLARE_NGINX_CONFIG} was left as it was."
	exit 1
fi
echo "✓ IP validation completed successfully"

IPV4_COUNT=$(grep -c . <<< "$IPV4_RANGES")
IPV6_COUNT=$(grep -c . <<< "$IPV6_RANGES")
echo "Downloaded $IPV4_COUNT IPv4 ranges and $IPV6_COUNT IPv6 ranges"

# In debug mode, show what was downloaded
if [[ "${DEBUG_INSTALL:-0}" == "1" ]]; then
	echo "Debug: IPv4 ranges downloaded:"
	echo "$IPV4_RANGES"
	echo "Debug: IPv6 ranges downloaded:"
	echo "$IPV6_RANGES"
fi

# Generate the new config in a staging file next to the live one,
# so a failed run never leaves a partly written cloudflare.conf in place
CLOUDFLARE_NGINX_CONFIG_NEW="${CLOUDFLARE_NGINX_CONFIG}.new"
CLOUDFLARE_NGINX_CONFIG_PREVIOUS="${CLOUDFLARE_NGINX_CONFIG}.previous"

echo "# Cloudflare IP addresses" > "$CLOUDFLARE_NGINX_CONFIG_NEW"
echo "# > IPv4" >> "$CLOUDFLARE_NGINX_CONFIG_NEW"

IPV4_PROCESSED=0
while IFS= read -r ip; do
	echo "set_real_ip_from $ip;" >> "$CLOUDFLARE_NGINX_CONFIG_NEW"
	((IPV4_PROCESSED++))
done <<< "$IPV4_RANGES"

echo "# > IPv6" >> "$CLOUDFLARE_NGINX_CONFIG_NEW"

IPV6_PROCESSED=0
while IFS= read -r ip; do
	echo "set_real_ip_from $ip;" >> "$CLOUDFLARE_NGINX_CONFIG_NEW"
	((IPV6_PROCESSED++))
done <<< "$IPV6_RANGES"

echo "real_ip_header CF-Connecting-IP;" >> "$CLOUDFLARE_NGINX_CONFIG_NEW"

echo "Processed $IPV4_PROCESSED IPv4 ranges and $IPV6_PROCESSED IPv6 ranges into config file"

# Swap the new file in, keeping the previous one for rollback
if [[ -f "$CLOUDFLARE_NGINX_CONFIG" ]]; then
	cp -p "$CLOUDFLARE_NGINX_CONFIG" "$CLOUDFLARE_NGINX_CONFIG_PREVIOUS"
fi
mv -f "$CLOUDFLARE_NGINX_CONFIG_NEW" "$CLOUDFLARE_NGINX_CONFIG"

# Test and reload Nginx only when it is running and no install or update is in progress.
# Installs and updates set ENGINESCRIPT_SKIP_NGINX_RELOAD=1 (or have Nginx stopped); they test
# the whole configuration and restart Nginx themselves, so a reload here would apply a
# half-updated configuration to the running Nginx.
if [[ "${ENGINESCRIPT_SKIP_NGINX_RELOAD:-0}" != "1" ]] && systemctl is-active --quiet nginx; then
	if /usr/sbin/nginx -t; then
		systemctl reload nginx
		rm -f "$CLOUDFLARE_NGINX_CONFIG_PREVIOUS"
	else
		echo "FAILED. Reason: nginx -t rejected the configuration. Restoring the previous Cloudflare IP list."
		if [[ -f "$CLOUDFLARE_NGINX_CONFIG_PREVIOUS" ]]; then
			mv -f "$CLOUDFLARE_NGINX_CONFIG_PREVIOUS" "$CLOUDFLARE_NGINX_CONFIG"
		fi
		exit 1
	fi
else
	rm -f "$CLOUDFLARE_NGINX_CONFIG_PREVIOUS"
fi
