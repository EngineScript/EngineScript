#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# A bash script to download the latest list of CloudFlare IP address
# ranges to be used with Nginx for the purpose of displaying a
# visitor's real IP address
#
# Author: Eric Mathison - https://ericmathison.com
# Modified: EngineScript - https://enginescript.com
#

# CloudFlare URLs where IP ranges are located at
CLOUDFLARE_IPSV4="https://www.cloudflare.com/ips-v4"
CLOUDFLARE_IPSV6="https://www.cloudflare.com/ips-v6"

# Nginx config file which contains CloudFlare's IP ranges
CLOUDFLARE_NGINX_CONFIG="/etc/nginx/globals/cloudflare.conf"

# Temporary file location
TEMP_FILE_IPV4="/tmp/cloudflare-ipv4"
TEMP_FILE_IPV6="/tmp/cloudflare-ipv6"

# Validate IPv4 CIDR addresses
validateIPv4() {
	regex="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$"
	while read ip
	do
		if [[ ! "$ip" =~ $regex ]]; then
			echo "FAILED. Reason: Invalid IPv4 address [$ip]"
			exit 1
		fi
	done < "$TEMP_FILE_IPV4"
}

# Validate IPv6 CIDR addresses
validateIPv6() {
	regex="^s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]d|1dd|[1-9]?d)(.(25[0-5]|2[0-4]d|1dd|[1-9]?d)){3}))|:)))(%.+)?s*(\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8]))?$"
	while read ip
	do
		if [[ ! "$ip" =~ $regex ]]; then
			echo "FAILED. Reason: Invalid IPv6 address [$ip]"
			exit 1
		fi
	done < "$TEMP_FILE_IPV6"
}

# Download the files from CloudFlare
if [ -f /usr/bin/curl ];
then
	# IPv4
	HTTP_STATUS=$(curl -sw '%{http_code}' -o /tmp/cloudflare-ipv4 $CLOUDFLARE_IPSV4)
	if [ "$HTTP_STATUS" -ne 200 ]; then
		echo "FAILED. Reason: unable to download IPv4 list [Status code: $HTTP_STATUS]"
		exit 1
	fi
	# IPv6
	HTTP_STATUS=$(curl -sw '%{http_code}' -o $TEMP_FILE_IPV6 $CLOUDFLARE_IPSV6)
	if [ "$HTTP_STATUS" -ne 200 ]; then
		echo "FAILED. Reason: unable to download IPv6 list [Status code: $HTTP_STATUS]"
		exit 1
	fi
else
	echo "FAILED. Reason: curl wasn't found on this system."
	exit 1
fi

# Validate IP addresses
validateIPv4
validateIPv6

# Generate the new config file with the latest IPs
echo "# CloudFlare IP addresses" > $CLOUDFLARE_NGINX_CONFIG
echo "# > IPv4" >> $CLOUDFLARE_NGINX_CONFIG

while read ip
do
	echo "set_real_ip_from $ip;" >> $CLOUDFLARE_NGINX_CONFIG
done< "$TEMP_FILE_IPV4"

echo "# > IPv6" >> $CLOUDFLARE_NGINX_CONFIG

while read ip
do
	echo "set_real_ip_from $ip;" >> $CLOUDFLARE_NGINX_CONFIG
done < "$TEMP_FILE_IPV6"

echo "real_ip_header CF-Connecting-IP;" >> $CLOUDFLARE_NGINX_CONFIG

# Clean-up temporary files
rm $TEMP_FILE_IPV4 $TEMP_FILE_IPV6

# Reload Nginx to implement changes
service nginx reload
