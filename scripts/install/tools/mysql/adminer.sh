#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Download Adminer beside the installed copy, and swap it in only when the download is complete
build_adminer() {
    download_file "https://www.adminer.org/latest.php" "$1/index.php" >&2 || return 1
    if ! head -c 5 "$1/index.php" | grep -q '<?php'; then
        echo "Error: The Adminer download is not a PHP file." >&2
        return 1
    fi
}
install_beside /var/www/admin/tools/adminer "Adminer" build_adminer || exit 1

# Set permissions (as www-data: the folder belongs to it, so a root chmod could follow a link)
set_www_data_tree /var/www/admin/tools/adminer

print_install_banner "Adminer"
