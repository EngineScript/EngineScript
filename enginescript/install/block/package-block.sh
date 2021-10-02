#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/VisiStruct/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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

cd /etc/apt/preferences.d/

# Block Apache2 from APT
echo -e "Package: apache2*\nPin: release *\nPin-Priority: -1" > apache2-block

# Block Nginx from APT
echo -e "Package: nginx*\nPin: release *\nPin-Priority: -1" > nginx-block

# Block Litespeed from APT
echo -e "Package: openlitespeed*\nPin: release *\nPin-Priority: -1" > litespeed-block
echo -e "Package: lighttpd*\nPin: release *\nPin-Priority: -1" > litespeed-block2

# Block PHP 5.x from APT
echo -e "Package: php5*\nPin: release *\nPin-Priority: -1" > php5-block

# Block PHP 7.0 from APT
echo -e "Package: php7.0*\nPin: release *\nPin-Priority: -1" > php70-block

# Block PHP 7.1 from APT
echo -e "Package: php7.1*\nPin: release *\nPin-Priority: -1" > php71-block

# Block PHP 7.2 from APT
echo -e "Package: php7.2*\nPin: release *\nPin-Priority: -1" > php72-block

# Block PHP 7.3 from APT
echo -e "Package: php7.3*\nPin: release *\nPin-Priority: -1" > php73-block

# Block PHP 7.4 from APT
echo -e "Package: php7.4*\nPin: release *\nPin-Priority: -1" > php74-block
