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

# Return to /usr/src
return_to_src

# Always download standard zlib (used as fallback and needed by default)
clean_directory "/usr/src/zlib-${ZLIB_VER}"
if [[ -f "/usr/src/zlib-${ZLIB_VER}.tar.gz" ]]; then
  rm -f "/usr/src/zlib-${ZLIB_VER}.tar.gz"
fi
download_and_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz" "/usr/src/zlib-${ZLIB_VER}.tar.gz" || { echo "Error: Failed to download/extract zlib." >&2; exit 1; }


#----------------------------------------------------------------------------------
# zlib-ng preparation (the default for new installs since 2026-11-20)

if [[ "${ZLIB_IMPLEMENTATION}" == "zlib-ng" ]]; then
  echo "============================================================="
  echo "  Preparing zlib-ng ${ZLIB_NG_VER}"
  echo "============================================================="

  # Return to /usr/src
  return_to_src

  clean_directory "/usr/src/zlib-ng-${ZLIB_NG_VER}"
  if [[ -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz" ]]; then
    rm -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz"
  fi

  download_and_extract "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_NG_VER}.tar.gz" "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz" || { echo "Error: Failed to download/extract zlib-ng." >&2; exit 1; }

  # Build zlib-ng here, before Nginx, into a folder of its own that only Nginx uses (as zlib-rs
  # below). The system's zlib (zlib1g, zlib1g-dev) stays installed for everything else.
  #
  # Nginx's --with-zlib cannot build zlib-ng: zlib-ng creates zlib.h when its configure runs,
  # which Nginx's Makefile does after compiling its own files when it compiles one file at a time
  # (1 CPU, or under 1.5 GB of memory), so the first file that needs zlib.h failed.
  #
  # --zlib-compat gives the standard zlib names (libz.a, deflate), not zlib-ng's own (zng_).
  # CFLAGS and the libz.a target are what Nginx's --with-zlib-opt=-fPIC build used; zlib-ng's
  # configure adds -O2, and zlib-ng picks its CPU-specific code when it runs.
  ZLIB_NG_PREFIX="/opt/zlib-ng"
  cd "/usr/src/zlib-ng-${ZLIB_NG_VER}" || { echo "Error: Failed to change to /usr/src/zlib-ng-${ZLIB_NG_VER}" >&2; exit 1; }
  CFLAGS="-fPIC" ./configure --zlib-compat --static > /dev/null \
    || { echo "Error: Failed to configure zlib-ng." >&2; exit 1; }
  make -j"$(nproc)" libz.a > /dev/null || { echo "Error: Failed to build zlib-ng." >&2; exit 1; }

  # zlib.h includes zconf.h, which includes zlib_name_mangling.h
  rm -rf "${ZLIB_NG_PREFIX}"
  mkdir -p "${ZLIB_NG_PREFIX}/lib" "${ZLIB_NG_PREFIX}/include"
  if ! cp libz.a "${ZLIB_NG_PREFIX}/lib/libz.a" \
    || ! cp zlib.h zconf.h zlib_name_mangling.h "${ZLIB_NG_PREFIX}/include/"; then
    echo "Error: Failed to install zlib-ng to ${ZLIB_NG_PREFIX}." >&2
    exit 1
  fi

  echo "zlib-ng ${ZLIB_NG_VER} built in ${ZLIB_NG_PREFIX}, for Nginx only"
fi


#----------------------------------------------------------------------------------
# Experimental: zlib-rs preparation

if [[ "${ZLIB_IMPLEMENTATION}" == "zlib-rs" ]]; then
  echo "============================================================="
  echo "  Preparing zlib-rs ${ZLIB_RS_VER} (experimental)"
  echo "============================================================="

  ZLIB_RS_PREFIX="/opt/zlib-rs"

  # Install Rust toolchain if not present
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Installing Rust toolchain (required for zlib-rs)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env" || { echo "Error: The Rust toolchain was not installed." >&2; exit 1; }
  fi

  echo "Rust version: $(rustc --version)"
  echo "Cargo version: $(cargo --version)"

  # Return to /usr/src
  return_to_src

  clean_directory "/usr/src/zlib-rs"
  git clone --quiet --branch "${ZLIB_RS_VER}" --depth 1 https://github.com/trifectatechfoundation/zlib-rs.git /usr/src/zlib-rs \
    || { echo "Error: Failed to clone zlib-rs ${ZLIB_RS_VER}." >&2; exit 1; }

  cd /usr/src/zlib-rs/libz-rs-sys-cdylib || { echo "Error: Failed to change to /usr/src/zlib-rs/libz-rs-sys-cdylib" >&2; exit 1; }

  # Build for a fixed CPU level (see get_x86_64_level in enginescript-common.sh)
  RUSTFLAGS="-Ctarget-cpu=$(get_x86_64_level) -Cllvm-args=-enable-dfa-jump-thread" \
    cargo build --release --features c-allocator \
    || { echo "Error: Failed to build zlib-rs." >&2; exit 1; }

  echo "zlib-rs library built successfully"

  # Install to a local prefix mimicking a standard zlib install
  rm -rf "${ZLIB_RS_PREFIX}"
  mkdir -p "${ZLIB_RS_PREFIX}/lib" "${ZLIB_RS_PREFIX}/include"

  # libz-rs-sys-cdylib is outside zlib-rs's Cargo workspace, so cargo writes to its own target folder
  if ! cp /usr/src/zlib-rs/libz-rs-sys-cdylib/target/release/libz_rs.a "${ZLIB_RS_PREFIX}/lib/libz.a" \
    || ! cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zlib.h "${ZLIB_RS_PREFIX}/include/" \
    || ! cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zconf.h "${ZLIB_RS_PREFIX}/include/"; then
    echo "Error: Failed to install zlib-rs to ${ZLIB_RS_PREFIX}." >&2
    exit 1
  fi

  echo "zlib-rs ${ZLIB_RS_VER} installed to ${ZLIB_RS_PREFIX}"
fi

# Return to /usr/src
return_to_src

echo "zlib completed successfully. Script done."
