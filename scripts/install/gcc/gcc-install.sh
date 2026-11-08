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

# GCC

# Remove previous GCC alternatives (a fresh server has none)
if update-alternatives --query gcc > /dev/null 2>&1; then
    update-alternatives --remove-all gcc
fi

# Each release's default GCC and the next version; the newer one compiles (Nginx, OpenSSL)
case "${UBUNTU_VERSION}" in
  24.04) GCC_VERSIONS=(14 13) ;;
  26.04) GCC_VERSIONS=(16 15) ;;
  *)
    echo "Error: No GCC versions are set for Ubuntu ${UBUNTU_VERSION}." >&2
    exit 1
    ;;
esac

for version in "${GCC_VERSIONS[@]}"; do
  apt-get install "g++-${version}" "gcc-${version}" -y || { echo "Error: Could not install GCC ${version}." >&2; exit 1; }
done

# Create new GCC alternatives: the first version gets the higher priority
priority=100
for version in "${GCC_VERSIONS[@]}"; do
  update-alternatives --install /usr/bin/gcc gcc "/usr/bin/gcc-${version}" "${priority}" \
    --slave /usr/bin/g++ g++ "/usr/bin/g++-${version}" --slave /usr/bin/gcov gcov "/usr/bin/gcov-${version}"
  priority=$((priority - 10))
done

echo "GCC completed successfully. Script done."
