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

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh
source /home/EngineScript/enginescript-install-options.txt

# Learn about Maldet at https://www.rfxn.com/appdocs/README.maldetect

# Update Maldet
maldet -d
maldet -u

# Start
for i in "${SITES[@]}"
do
	cd "$ROOT/$i/html"
	# Scan WordPress wp-content for Malware & Viruses
	maldet -a -b -r /wp-content 30
	clamscan -ir /wp-content

#Placeholder for 10up WP CLI Vuln Scanner

done
