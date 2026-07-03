#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

#----------------------------------------------------------------------------

# Update WP-CLI
WP_CLI_BIN="/usr/local/bin/wp"
if [[ ! -x "${WP_CLI_BIN}" ]]; then
    if command -v wp >/dev/null 2>&1; then
        WP_CLI_BIN="$(command -v wp)"
    else
        echo "WP-CLI not found. Expected executable at /usr/local/bin/wp." | tee -a /tmp/enginescript_install_errors.log >&2
        exit 1
    fi
fi

configure_wp_cli_package_fetching() {
    export COMPOSER_ALLOW_SUPERUSER=1
    export COMPOSER_HOME="${COMPOSER_HOME:-/tmp/enginescript-composer}"
    mkdir -p "${COMPOSER_HOME}" || { echo "Error: Failed to create Composer home at ${COMPOSER_HOME}" >&2; exit 1; }

    # shellcheck disable=SC2016
    php -r '
        $composerHome = rtrim($argv[1] ?? "", "/");
        if ($composerHome === "") {
            fwrite(STDERR, "Error: Composer home was not provided\n");
            exit(1);
        }
        $file = $composerHome . "/config.json";
        $config = [];
        if (is_file($file)) {
            $contents = file_get_contents($file);
            if ($contents !== false && trim($contents) !== "") {
                $decoded = json_decode($contents, true);
                if (!is_array($decoded)) {
                    fwrite(STDERR, "Error: Invalid Composer config JSON at {$file}\n");
                    exit(1);
                }
                $config = $decoded;
            }
        }
        if (!isset($config["config"]) || !is_array($config["config"])) {
            $config["config"] = [];
        }
        $config["config"]["github-protocols"] = ["https"];
        $config["config"]["use-github-api"] = false;
        $json = json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if ($json === false || file_put_contents($file, $json . PHP_EOL) === false) {
            fwrite(STDERR, "Error: Failed to write Composer config at {$file}\n");
            exit(1);
        }
    ' "${COMPOSER_HOME}" || exit 1

    local git_config_count=0
    if [[ "${GIT_CONFIG_COUNT:-}" =~ ^[0-9]+$ ]]; then
        git_config_count="${GIT_CONFIG_COUNT}"
    fi

    export GIT_CONFIG_COUNT=$((git_config_count + 2))
    export "GIT_CONFIG_KEY_${git_config_count}=url.https://github.com/.insteadOf"
    export "GIT_CONFIG_VALUE_${git_config_count}=git@github.com:"

    local next_git_config=$((git_config_count + 1))
    export "GIT_CONFIG_KEY_${next_git_config}=url.https://github.com/.insteadOf"
    export "GIT_CONFIG_VALUE_${next_git_config}=ssh://git@github.com/"
}

configure_wp_cli_package_fetching

# The intent is to fail when either command fails 
if ! "${WP_CLI_BIN}" cli update --stable --allow-root --yes 2>> /tmp/enginescript_install_errors.log \
    || ! "${WP_CLI_BIN}" package update --allow-root --yes 2>> /tmp/enginescript_install_errors.log; then
    echo "WP-CLI update failed. See /tmp/enginescript_install_errors.log for details." >&2
    exit 1
fi
set_install_state "WP_CLI" "1"
print_last_errors
debug_pause "WP-CLI Update"
