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

# Add UFW Rules for Cloudflare
# Credit: https://github.com/Paul-Reed/cloudflare-ufw

# Download and check Cloudflare's IP ranges (cf_ip_ranges retries, and returns 1 when the
# download fails or any line is not an address range, so nothing else becomes a firewall rule)
if ! cloudflare_ips_v4="$(cf_ip_ranges v4)" || ! cloudflare_ips_v6="$(cf_ip_ranges v6)"; then
  echo "${BOLD}ERROR:${NORMAL} Could not get Cloudflare's IP ranges. Please check network connectivity and Cloudflare status." >&2
  exit 1
fi
cloudflare_ips="$(printf '%s\n%s\n' "${cloudflare_ips_v4}" "${cloudflare_ips_v6}")"

echo "Adding UFW rules for Cloudflare IPs (TCP & UDP)..."
# Allow all TCP and UDP traffic from Cloudflare IPs (no ports restriction)
while IFS= read -r cfip; do
  # Skip empty lines if any
  if [[ -z "$cfip" ]]; then
    continue
  fi
  # Add the TCP and UDP rules; warn when either fails
  if ! ufw allow proto tcp from "$cfip" comment 'Cloudflare IP (TCP)' > /dev/null 2>&1 \
      || ! ufw allow proto udp from "$cfip" comment 'Cloudflare IP (UDP)' > /dev/null 2>&1; then
    echo "Warning: Failed to add rule for $cfip"
  fi
done <<< "$cloudflare_ips"

echo "Reloading UFW rules..."
ufw reload > /dev/null
echo "UFW rules updated for Cloudflare."
