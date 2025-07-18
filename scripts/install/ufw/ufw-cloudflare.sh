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

# Add UFW Rules for Cloudflare
# Credit: https://github.com/Paul-Reed/cloudflare-ufw

# Fetch Cloudflare IP ranges with retry logic
max_retries=3
retry_delay=10
retry_count=0
cloudflare_ips=""

while [[ $retry_count -lt $max_retries ]]; do
  echo "Fetching Cloudflare IP ranges... (Attempt $((retry_count+1))/$max_retries)"
  cloudflare_ips_v4=$(curl -s https://www.cloudflare.com/ips-v4)
  cloudflare_ips_v6=$(curl -s https://www.cloudflare.com/ips-v6)
  cloudflare_ips=$(echo "$cloudflare_ips_v4"; echo "$cloudflare_ips_v6")
  if [[ -n "$cloudflare_ips_v4" ]] && [[ -n "$cloudflare_ips_v6" ]]; then
    break
  fi
  retry_count=$((retry_count+1))
  if [[ $retry_count -lt $max_retries ]]; then
    echo "Failed to fetch Cloudflare IP ranges. Retrying in $retry_delay seconds..."
    sleep $retry_delay
  fi

done

# Check if IPs were fetched
if [[ -z "$cloudflare_ips_v4" ]] || [[ -z "$cloudflare_ips_v6" ]]; then
  echo "${BOLD}ERROR:${NORMAL} Failed to fetch Cloudflare IP ranges after $max_retries attempts. Please check network connectivity and Cloudflare status."
  exit 1
fi

echo "Adding UFW rules for Cloudflare IPs (TCP & UDP)..."
# Allow all TCP and UDP traffic from Cloudflare IPs (no ports restriction)
while IFS= read -r cfip; do
  # Skip empty lines if any
  if [[ -z "$cfip" ]]; then
    continue
  fi
  # Add rules, redirecting output to /dev/null as before
  ufw allow proto tcp from "$cfip" comment 'Cloudflare IP (TCP)' > /dev/null 2>&1
  ufw allow proto udp from "$cfip" comment 'Cloudflare IP (UDP)' > /dev/null 2>&1
  # Check exit status of ufw command (optional, but good for debugging)
   if [[ $? -ne 0 ]]; then
     echo "Warning: Failed to add rule for $cfip"
   fi
done <<< "$cloudflare_ips"

echo "Reloading UFW rules..."
ufw reload > /dev/null
echo "UFW rules updated for Cloudflare."
