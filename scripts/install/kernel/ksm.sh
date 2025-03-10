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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Install
apt-get install -qy ksmtuned --no-install-recommends
sudo systemctl enable --now ksm.service
mkdir -p /opt/kernel-samepage-merging/
cp -rf /usr/local/bin/enginescript/config/etc/systemd/system/ksm.service /etc/systemd/system/ksm.service
cp -rf /usr/local/bin/enginescript/config/opt/kernel-samepage-merging/ksm-service.sh /opt/kernel-samepage-merging/ksm-service.sh
echo 'w /sys/kernel/mm/ksm/run - - - - 1' >> /etc/tmpfiles.d/ksm.conf

# Persmissions
chmod +x /opt/kernel-samepage-merging/ksm-service.sh
chmod 644 /opt/kernel-samepage-merging/ksm-service.sh
chmod +x /etc/systemd/system/ksm.service
chmod 644 /etc/systemd/system/ksm.service
systemctl daemon-reload
