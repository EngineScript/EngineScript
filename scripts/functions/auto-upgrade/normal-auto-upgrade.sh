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

# Upgrade Scripts will be found below:

# Fix MariaDB configuration - replace MySQL-specific log_error_verbosity with MariaDB log_warnings
if [[ -f "/etc/mysql/my.cnf" ]]; then
    sed -i 's/log_error_verbosity/log_warnings/g' /etc/mysql/my.cnf
fi

