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


# Helper function for retrying add-apt-repository up to 3 times with 5s delay
retry_add_ppa() {
  local ppa="$1"
  local max_retries=3
  local delay=5
  local attempt=1
  while [[ $attempt -le $max_retries ]]; do
    add-apt-repository -yn "$ppa" && return 0
    echo "Attempt $attempt to add $ppa failed. Retrying in $delay seconds..."
    attempt=$((attempt+1))
    sleep $delay
  done
  echo "Failed to add $ppa after $max_retries attempts. Exiting."
  exit 1
}

#----------------------------------------------------------------------------------
# Start Main Script

source /etc/enginescript/install-state.conf
if [[ "${REPOS}" = 1 ]]; then
    echo "REPOS script has already run"
    exit 0
fi

# PPAs: Canonical's server backports, MaxMind (GeoIP), Git, Hurl, and deadsnakes (Python); the
# list is ENGINESCRIPT_PPAS in enginescript-common.sh. A PPA with no packages for this Ubuntu
# release yet would leave apt with a source it cannot read, so it is skipped now, and the weekly
# maintenance job tries it again (add_missing_ppas in weekly-maintenance.sh).
for ppa in "${ENGINESCRIPT_PPAS[@]}"; do
  if ppa_has_release "${ppa}"; then
    retry_add_ppa "${ppa}"
  else
    echo "Skipping ${ppa} for now: it has no packages for Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}) yet. The weekly maintenance job tries it again."
  fi
done

# Docker
curl -fsSL --proto '=https' https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list

# ElasticSearch
curl -fsSL --proto '=https' https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list

# GoAccess
curl -fsSL --proto '=https' https://deb.goaccess.io/gnugpg.key | gpg --dearmor | tee /usr/share/keyrings/goaccess.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/goaccess.gpg arch=$(dpkg --print-architecture)] https://deb.goaccess.io/ ${UBUNTU_CODENAME} main" | tee /etc/apt/sources.list.d/goaccess.list

# Google gcloud CLI
curl -fsSL --proto '=https' https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Grafana
curl -fsSL --proto '=https' https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

# PHP
install_php_repository() {
  local ubuntu_codename
  local sury_keyring_deb="/tmp/debsuryorg-archive-keyring.deb"

  ubuntu_codename="${UBUNTU_CODENAME}"

  # Disable legacy or stale PHP sources when migrating an existing install.
  find /etc/apt/sources.list.d/ -type f \( -name '*.list' -o -name '*.sources' \) \
    -exec grep -lE 'ondrej/php|ppa\.launchpad(content)?\.net/ondrej/php|packages\.sury\.org/php' {} + \
    | while IFS= read -r apt_source; do
        mv "${apt_source}" "${apt_source}.save"
      done

  curl -fsSL --proto '=https' -o "${sury_keyring_deb}" "https://packages.sury.org/debsuryorg-archive-keyring.deb" || {
    echo "Error: Failed to download the DEB.SURY.ORG archive keyring."
    exit 1
  }

  dpkg -i "${sury_keyring_deb}" || {
    echo "Error: Failed to install the DEB.SURY.ORG archive keyring."
    exit 1
  }
  rm -f "${sury_keyring_deb}"

  if [[ ! -s /usr/share/keyrings/debsuryorg-archive-keyring.gpg ]]; then
    echo "Error: DEB.SURY.ORG archive keyring was not installed."
    exit 1
  fi

  echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${ubuntu_codename} main" | tee /etc/apt/sources.list.d/php.list
}
install_php_repository

# Redis
curl -fsSL --proto '=https' https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb ${UBUNTU_CODENAME} main" | tee /etc/apt/sources.list.d/redis.list

# Universe
retry_add_ppa universe

# Yarn
curl -fsSL --proto '=https' https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Mark the installation as complete
set_install_state "REPOS" "1"
echo "Install Repositories completed successfully. Script done."
