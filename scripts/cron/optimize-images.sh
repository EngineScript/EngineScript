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

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh

for i in "${SITES[@]}"
do
	cd "$ROOT/$i/html"

	# zImageCompress
	# This script will attempt to perform a lossless optimization on images found within your web-facing directories.
	# Using the -n option, we the script will only attempt to optimize files that are new since last running the script.
	/usr/local/bin/zimageoptimizer/zImageOptimizer.sh -p /wp-content/uploads -n -q

	# Exiftool
	# Strips Exif data from images
	exiftool -recurse -overwrite_original -EXIF= -ext jpg -ext jpeg /wp-content

done
