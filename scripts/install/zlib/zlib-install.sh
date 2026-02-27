#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
cd /usr/src

# Always download standard zlib (used as fallback and needed by default)
clean_directory "/usr/src/zlib-${ZLIB_VER}"
if [[ -f "/usr/src/zlib-${ZLIB_VER}.tar.gz" ]]; then
  rm -f "/usr/src/zlib-${ZLIB_VER}.tar.gz"
fi
download_and_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz" "/usr/src/zlib-${ZLIB_VER}.tar.gz"


#----------------------------------------------------------------------------------
# Experimental: zlib-ng preparation

if [[ "${ZLIB_IMPLEMENTATION}" == "zlib-ng" ]]; then
  echo "============================================================="
  echo "  Preparing zlib-ng ${ZLIB_NG_VER} (experimental)"
  echo "============================================================="

  cd /usr/src

  clean_directory "/usr/src/zlib-ng-${ZLIB_NG_VER}"
  if [[ -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz" ]]; then
    rm -f "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz"
  fi

  download_and_extract "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_NG_VER}.tar.gz" "/usr/src/zlib-ng-${ZLIB_NG_VER}.tar.gz"

  # Create a configure wrapper
  #
  # Nginx's build system calls ./configure with NO arguments in the zlib
  # source dir. zlib-ng REQUIRES --zlib-compat to produce a standard
  # zlib-compatible API (libz.a with standard symbol names).
  # Without it, zlib-ng produces libz-ng.a with zng_ prefixed symbols.
  #
  # Solution: rename the real configure and create a wrapper that always
  # passes --zlib-compat.
  cd "/usr/src/zlib-ng-${ZLIB_NG_VER}"
  mv configure configure.zlib-ng
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
    source "$HOME/.cargo/env"
  fi

  echo "Rust version: $(rustc --version)"
  echo "Cargo version: $(cargo --version)"

  cd /usr/src

  clean_directory "/usr/src/zlib-rs"
  git clone --branch "${ZLIB_RS_VER}" --depth 1 https://github.com/trifectatechfoundation/zlib-rs.git /usr/src/zlib-rs

  cd /usr/src/zlib-rs/libz-rs-sys-cdylib

  # Build with native CPU optimizations for best performance
  RUSTFLAGS="-Ctarget-cpu=native -Cllvm-args=-enable-dfa-jump-thread" \
    cargo build --release --features c-allocator

  echo "zlib-rs library built successfully"

  # Install to a local prefix mimicking a standard zlib install
  rm -rf "${ZLIB_RS_PREFIX}"
  mkdir -p "${ZLIB_RS_PREFIX}/lib" "${ZLIB_RS_PREFIX}/include"

  cp /usr/src/zlib-rs/target/release/libz_rs.a "${ZLIB_RS_PREFIX}/lib/libz.a"
  cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zlib.h "${ZLIB_RS_PREFIX}/include/"
  cp /usr/src/zlib-rs/libz-rs-sys-cdylib/include/zconf.h "${ZLIB_RS_PREFIX}/include/"

  echo "zlib-rs ${ZLIB_RS_VER} installed to ${ZLIB_RS_PREFIX}"
fi

# Return to /usr/src
cd /usr/src
