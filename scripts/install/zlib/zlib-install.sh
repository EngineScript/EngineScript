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

source /etc/enginescript/install-state.conf
# ES_REFRESH_SOURCES=1 (from nginx-update.sh): fetch the current version even after the install
if [[ "${ZLIB}" = 1 && "${ES_REFRESH_SOURCES:-0}" != 1 ]]; then
    echo "ZLIB script has already run"
    exit 0
fi

# Return to /usr/src
return_to_src

# Always download standard zlib (used as fallback and needed by default)
clean_directory "/usr/src/zlib-${ZLIB_VER}"
if [[ -f "/usr/src/zlib-${ZLIB_VER}.tar.gz" ]]; then
  rm -f "/usr/src/zlib-${ZLIB_VER}.tar.gz"
fi
download_and_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz" "/usr/src/zlib-${ZLIB_VER}.tar.gz" || { echo "Error: Failed to download/extract zlib." >&2; exit 1; }


#----------------------------------------------------------------------------------
# Experimental: zlib-ng preparation

if [[ "${ZLIB_IMPLEMENTATION}" == "zlib-ng" ]]; then
  echo "============================================================="
  echo "  Preparing zlib-ng ${ZLIB_NG_VER} (experimental)"
  echo "============================================================="

  # Return to /usr/src
  return_to_src

  clean_directory "/usr/src/zlib-ng-${ZLIB_NG_VER}"
  if [[ -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz" ]]; then
    rm -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz"
  fi

  download_and_extract "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_NG_VER}.tar.gz" "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz" || { echo "Error: Failed to download/extract zlib-ng." >&2; exit 1; }

  # Create a configure wrapper
  #
  # Nginx's build system calls ./configure with NO arguments in the zlib
  # source dir. zlib-ng REQUIRES --zlib-compat to produce a standard
  # zlib-compatible API (libz.a with standard symbol names).
  # Without it, zlib-ng produces libz-ng.a with zng_ prefixed symbols.
  #
  # Solution: rename the real configure and create a wrapper that always
  # passes --zlib-compat.
  cd "/usr/src/zlib-ng-${ZLIB_NG_VER}" || { echo "Error: Failed to change to /usr/src/zlib-ng-${ZLIB_NG_VER}" >&2; exit 1; }
  mv configure configure.zlib-ng || { echo "Error: zlib-ng has no configure script to wrap." >&2; exit 1; }
  cat > configure << 'WRAPPER'
#!/bin/sh
exec "$(dirname "$0")/configure.zlib-ng" --zlib-compat "$@"
WRAPPER
  chmod +x configure

  # Stub Makefile so nginx's "make distclean" succeeds before configure runs.
  # Overwritten when ./configure generates the real Makefile.
  cat > Makefile << 'STUBMAKE'
.PHONY: distclean clean
distclean clean:
	@echo "stub: no-op (pre-configure)"
STUBMAKE

  echo "zlib-ng ${ZLIB_NG_VER} prepared for Nginx compilation"
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
  git clone --branch "${ZLIB_RS_VER}" --depth 1 https://github.com/trifectatechfoundation/zlib-rs.git /usr/src/zlib-rs \
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

  if ! cp /usr/src/zlib-rs/target/release/libz_rs.a "${ZLIB_RS_PREFIX}/lib/libz.a" \
    || ! cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zlib.h "${ZLIB_RS_PREFIX}/include/" \
    || ! cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zconf.h "${ZLIB_RS_PREFIX}/include/"; then
    echo "Error: Failed to install zlib-rs to ${ZLIB_RS_PREFIX}." >&2
    exit 1
  fi

  echo "zlib-rs ${ZLIB_RS_VER} installed to ${ZLIB_RS_PREFIX}"
fi

# Return to /usr/src
return_to_src

# Mark the installation as complete
set_install_state "ZLIB" "1"
echo "zlib completed successfully. Script done."
