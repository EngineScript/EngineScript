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

# The nightly build until a WP-CLI release keeps WordPress 7's long core paths intact on
# "wp core download" (see wp-cli-install.sh). The nightly is WP-CLI 3, whose "package update"
# takes --no-interaction instead of --yes; it runs after "cli update", so on the nightly.
if ! "${WP_CLI_BIN}" cli update --nightly --allow-root --yes 2>> /tmp/enginescript_install_errors.log; then
    echo "WP-CLI update failed. See /tmp/enginescript_install_errors.log for details." >&2
    exit 1
fi

# Older installs pinned doctor-command to 2.3.1, which "package update" never moves past.
# Installing it again with @stable lifts the pin, as the install now does.
WP_CLI_PACKAGES_JSON="$("${WP_CLI_BIN}" package path --allow-root 2> /dev/null)/composer.json"
if grep -qE '"wp-cli\\?/doctor-command"[[:space:]]*:[[:space:]]*"[0-9]' "${WP_CLI_PACKAGES_JSON}" 2> /dev/null; then
    "${WP_CLI_BIN}" package install "wp-cli/doctor-command:@stable" --allow-root 2>> /tmp/enginescript_install_errors.log \
        || echo "Warning: Failed to move WP-CLI package wp-cli/doctor-command to @stable." >&2
fi

# The packages add commands; WP-CLI works without them, so a package update failure is only reported
if ! "${WP_CLI_BIN}" package update --allow-root --no-interaction 2>> /tmp/enginescript_install_errors.log; then
    echo "Warning: Updating the WP-CLI packages failed; WP-CLI itself is up to date. See /tmp/enginescript_install_errors.log for details." >&2
fi
set_install_state "WP_CLI" "1"
print_last_errors
debug_pause "WP-CLI Update"
