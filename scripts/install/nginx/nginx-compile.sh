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

# Compile Nginx
cd "/usr/src/nginx-${NGINX_VER}" || { echo "Error: Nginx source directory /usr/src/nginx-${NGINX_VER} not found." >&2; exit 1; }

# Detect best linker: prefer lld, fallback to gold, else use default
# Further testing needed: https://lld.llvm.org/
if command -v ld.lld >/dev/null 2>&1; then
  LD_FLAG="-fuse-ld=lld"
elif command -v ld.gold >/dev/null 2>&1; then
  LD_FLAG="-fuse-ld=gold"
else
  LD_FLAG=""
fi

# CPU target: x86-64-v3 (Intel Haswell 2013+, AMD Zen 2017+), or x86-64-v2 on CPUs that
# cannot run it. See get_x86_64_level in enginescript-common.sh for why -march=native is not used.
X86_64_LEVEL="$(get_x86_64_level)"
if [[ "${X86_64_LEVEL}" != "x86-64-v3" ]]; then
  echo "This CPU does not support x86-64-v3; compiling for ${X86_64_LEVEL}."
fi
ARCH_FLAGS="-march=${X86_64_LEVEL} -mtune=generic"
echo "CPU target compiler flags: ${ARCH_FLAGS}"
echo "------------------------------------------------"

# Define compiler and linker flags as variables for easier maintenance
# Nginx's build already treats compiler warnings as errors (-Werror); no warnings are suppressed.
CC_OPT_FLAGS="$ARCH_FLAGS -DTCP_FASTOPEN=23 -O3 -fcode-hoisting -flto=auto -fPIC -fstack-protector-strong $LD_FLAG -Werror=format-security -Wformat --param=ssp-buffer-size=4"
LD_OPT_FLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-s -fPIC -flto=auto $LD_FLAG"

# Set OpenSSL test flag based on debug mode
if [[ "${DEBUG_INSTALL}" == "1" ]]; then
  OPENSSL_TESTS_FLAG=""
else
  OPENSSL_TESTS_FLAG="no-tests"
fi

# OpenSSL's deprecated functions stay in the build: Nginx still calls some (it defines
# OPENSSL_SUPPRESS_DEPRECATED for them), and no-deprecated removed X509_check_host and
# X509_check_ip once OpenSSL 4.1 deprecated them. Nginx links OpenSSL statically, so functions it
# does not call never reach the binary. SSLv3 is gone from OpenSSL 4, so no-ssl3-method is not set.
OPENSSL_OPT_FLAGS="enable-ec_nistp_64_gcc_128 enable-ktls no-psk no-srp no-tls1-method no-tls1_1-method no-weak-ssl-ciphers $OPENSSL_TESTS_FLAG"

# Determine zlib implementation flags for nginx configure
ZLIB_CC_EXTRA=""
ZLIB_LD_EXTRA=""
ZLIB_CONFIGURE_FLAGS=()
ZLIB_BUILD_TAG=""

case "${ZLIB_IMPLEMENTATION}" in
  zlib-ng)
    ZLIB_CONFIGURE_FLAGS=(
      --with-zlib="/usr/src/zlib-ng-${ZLIB_NG_VER}"
      --with-zlib-opt=-fPIC
    )
    ZLIB_BUILD_TAG="-zlibng"
    echo "Using zlib-ng ${ZLIB_NG_VER} for Nginx compilation"
    ;;
  zlib-rs)
    ZLIB_RS_PREFIX="/opt/zlib-rs"
    ZLIB_CC_EXTRA="-I${ZLIB_RS_PREFIX}/include"
    ZLIB_LD_EXTRA="-L${ZLIB_RS_PREFIX}/lib"
    ZLIB_BUILD_TAG="-zlibrs"
    echo "Using zlib-rs ${ZLIB_RS_VER} for Nginx compilation"
    ;;
  *)
    ZLIB_CONFIGURE_FLAGS=(
      --with-zlib="/usr/src/zlib-${ZLIB_VER}"
      --with-zlib-opt=-fPIC
    )
    echo "Using standard zlib ${ZLIB_VER} for Nginx compilation"
    ;;
esac

# Append zlib extras to compiler/linker flags
if [[ -n "$ZLIB_CC_EXTRA" ]]; then
  CC_OPT_FLAGS="$CC_OPT_FLAGS $ZLIB_CC_EXTRA"
fi
if [[ -n "$ZLIB_LD_EXTRA" ]]; then
  LD_OPT_FLAGS="$LD_OPT_FLAGS $ZLIB_LD_EXTRA"
fi

# Configure options, listed once. The HTTP/3 module is added only when INSTALL_HTTP3=1.
CONFIGURE_ARGS=(
  --prefix=/etc/nginx
  --conf-path=/etc/nginx/nginx.conf
  --user=www-data
  --group=www-data
  --error-log-path=/var/log/nginx/nginx.error.log
  --http-client-body-temp-path=/var/lib/nginx/body
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi
  --http-log-path=/var/log/nginx/nginx.access.log
  --http-proxy-temp-path=/var/lib/nginx/proxy
  --lock-path=/run/lock/nginx.lock
  --modules-path=/etc/nginx/modules
  --pid-path=/run/nginx.pid
  --sbin-path=/usr/sbin/nginx
  --build="nginx-${NGINX_VER}-${DT}-enginescript${ZLIB_BUILD_TAG}"
  --builddir="nginx-${NGINX_VER}"
  --with-cc-opt="$CC_OPT_FLAGS"
  --with-ld-opt="$LD_OPT_FLAGS"
  --with-openssl-opt="$OPENSSL_OPT_FLAGS"
  --with-openssl="/usr/src/openssl-${OPENSSL_VER}"
  --with-libatomic
  --with-file-aio
  --with-threads
  --with-pcre="/usr/src/pcre2-${PCRE2_VER}"
  --with-pcre-jit
  "${ZLIB_CONFIGURE_FLAGS[@]}"
  --with-http_ssl_module
  --with-http_v2_module
  --with-http_realip_module
  --add-module="/usr/src/headers-more-nginx-module-${NGINX_HEADER_VER}"
  --add-module=/usr/src/ngx_brotli
  --add-module="/usr/src/ngx_cache_purge-${NGINX_PURGE_VER}"
  --without-http_browser_module
  --without-http_empty_gif_module
  --without-http_memcached_module
  --without-http_scgi_module
  --without-http_split_clients_module
  --without-http_userid_module
  --without-http_uwsgi_module
  --without-mail_imap_module
  --without-mail_pop3_module
  --without-mail_smtp_module
)

if [[ "${INSTALL_HTTP3}" == "1" ]]; then
  CONFIGURE_ARGS+=(--with-http_v3_module)
fi

./configure "${CONFIGURE_ARGS[@]}" || { echo "Error: Nginx configure failed." >&2; exit 1; }

make -j"${CPU_COUNT}" || { echo "Error: Nginx build failed." >&2; exit 1; }
find "/usr/src/nginx-${NGINX_VER}" | xargs file | grep ELF | cut -f 1 -d : | xargs strip --strip-unneeded

# make install renames the running binary to nginx.old before copying the new one, so a
# running Nginx keeps serving. The caller (install or update script) restarts it.
make install || { echo "Error: Nginx install (make install) failed." >&2; exit 1; }

# Remove .default Files
rm -rf /etc/nginx/{*.default,*.dpkg-dist}

# Remove debug symbols
strip -s /usr/sbin/nginx*

checksec --format=json --file="/usr/sbin/nginx" --extended | jq -r

# Return to /usr/src
return_to_src
