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

# WP-CLI
cd /usr/local/src || { echo "Error: Failed to change directory to /usr/local/src" >&2; exit 1; }
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
WP_CLI_BIN="/usr/local/bin/wp"

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

install_wp_cli_package() {
    local package="$1"

    if ! "${WP_CLI_BIN}" package install "${package}" --allow-root; then
        echo "Error: Failed to install WP-CLI package ${package}." >&2
        exit 1
    fi
}

mkdir -p /tmp/wp-cli-phar
chown -R www-data:www-data /tmp/wp-cli-phar
chmod 775 /tmp/wp-cli-phar
mkdir -p ~/.wp-cli/cache
chown -R www-data:www-data ~/.wp-cli/cache
chmod 775 ~/.wp-cli/cache

# Install WP-CLI Extensions
configure_wp_cli_package_fetching
install_wp_cli_package "pantheon-systems/wp_launch_check:@stable"
install_wp_cli_package "wp-cli/doctor-command:2.3.1"

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}WP-CLI installed.${NORMAL}"
echo ""
echo "Learn about WP-CLI"
echo "https://make.wordpress.org/cli/handbook/"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
