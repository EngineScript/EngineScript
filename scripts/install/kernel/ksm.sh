#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

# Install
apt-get install ksmtuned --no-install-recommends
sudo systemctl enable --now ksm.service
mkdir -p /opt/kernel-samepage-merging/
cp -p /usr/local/bin/enginescript/etc/systemd/system/ksm.service /etc/systemd/system/ksm.service
cp -p /usr/local/bin/enginescript/opt/kernel-samepage-merging/ksm-service.sh /opt/kernel-samepage-merging/ksm-service.sh
echo 'w /sys/kernel/mm/ksm/run - - - - 1' >> /etc/tmpfiles.d/ksm.conf

# Persmissions
chmod +x /opt/kernel-samepage-merging/ksm-service.sh
chmod 644 /opt/kernel-samepage-merging/ksm-service.sh
chmod +x /etc/systemd/system/ksm.service
chmod 644 /etc/systemd/system/ksm.service
systemctl daemon-reload
