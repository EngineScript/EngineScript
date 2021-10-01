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

# Tuning-Primer
mkdir -p /usr/local/bin/tuning-primer
wget https://raw.githubusercontent.com/BMDan/tuning-primer.sh/master/tuning-primer.sh -O /usr/local/bin/tuning-primer/tuning-primer.sh

# Set Permissions
chmod 755 /usr/local/bin/tuning-primer/tuning-primer.sh

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Tuning-Primer installed.${NORMAL}"
echo ""
echo "To run Tuning-Primer:"
echo "/usr/local/bin/tuning-primer/tuning-primer.sh"
echo ""
echo "Retrieve your MySQL login details by entering ES.MYSQL in console prior to running Tuning-Primer"
echo "============================================================="
echo ""
echo ""

sleep 5
