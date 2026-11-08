#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# The template for /home/EngineScript/sites-list/sites.sh, the list of the server's sites. Scripts
# source that file after loading EngineScript's settings, so it holds only the SITES array
# (Create Domain and Import Domain add each domain on its own line).

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Tasks to be performed on the following sites
# shellcheck disable=SC2034  # read by the scripts that source the site list
SITES=(
)
