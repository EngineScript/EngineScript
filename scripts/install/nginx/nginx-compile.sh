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



#----------------------------------------------------------------------------------
# Start Main Script

# Compile Nginx
cd /usr/src/nginx-${NGINX_VER}

# Detect best linker: prefer lld, fallback to gold, else use default
# Further testing needed: https://lld.llvm.org/
if command -v ld.lld >/dev/null 2>&1; then
  LD_FLAG="-fuse-ld=lld"
elif command -v ld.gold >/dev/null 2>&1; then
  LD_FLAG="-fuse-ld=gold"
else
  LD_FLAG=""
fi

# Get CPU architecture and optimizations
echo "Detecting CPU architecture and capabilities..."
# Save CPU flags to a temporary file
gcc -c -Q -march=native --help=target > /tmp/cpu_capabilities.txt

# Initialize optimization flags
ARCH_FLAGS="-march=native -mtune=native"
VECTOR_FLAGS=""
CRYPTO_FLAGS=""
BIT_FLAGS=""
OTHER_FLAGS=""

# Check for AVX/AVX2 support
if grep -q "\-mavx.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  VECTOR_FLAGS="$VECTOR_FLAGS -mavx"
fi
if grep -q "\-mavx2.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  VECTOR_FLAGS="$VECTOR_FLAGS -mavx2"
fi

# Check for AES and other crypto extensions
if grep -q "\-maes.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  CRYPTO_FLAGS="$CRYPTO_FLAGS -maes"
fi
if grep -q "\-mrdrnd.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  CRYPTO_FLAGS="$CRYPTO_FLAGS -mrdrnd"
fi
if grep -q "\-mrdseed.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  CRYPTO_FLAGS="$CRYPTO_FLAGS -mrdseed"
fi

# Check for bit manipulation instructions
if grep -q "\-mbmi.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  BIT_FLAGS="$BIT_FLAGS -mbmi"
fi
if grep -q "\-mbmi2.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  BIT_FLAGS="$BIT_FLAGS -mbmi2"
fi
if grep -q "\-mlzcnt.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  BIT_FLAGS="$BIT_FLAGS -mlzcnt"
fi

# Check for other useful extensions
if grep -q "\-mfsgsbase.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  OTHER_FLAGS="$OTHER_FLAGS -mfsgsbase"
fi
if grep -q "\-mprfchw.*\[enabled\]" /tmp/cpu_capabilities.txt; then
  OTHER_FLAGS="$OTHER_FLAGS -mprfchw"
fi

# Combine all flags
CPU_SPECIFIC_FLAGS="$ARCH_FLAGS $VECTOR_FLAGS $CRYPTO_FLAGS $BIT_FLAGS $OTHER_FLAGS"

echo "CPU-specific compiler flags: $CPU_SPECIFIC_FLAGS"
echo "------------------------------------------------"

# Clean up
rm -f /tmp/cpu_capabilities.txt

if [[ "${INSTALL_HTTP3}" == "1" ]];
  then
    # HTTP3
    ./configure \
      --prefix=/etc/nginx \
      --conf-path=/etc/nginx/nginx.conf \
      --user=www-data \
      --group=www-data \
      --error-log-path=/var/log/nginx/nginx.error.log \
      --http-client-body-temp-path=/var/lib/nginx/body \
      --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
      --http-log-path=/var/log/nginx/nginx.access.log \
      --http-proxy-temp-path=/var/lib/nginx/proxy \
      --lock-path=/run/lock/nginx.lock \
      --modules-path=/etc/nginx/modules \
      --pid-path=/run/nginx.pid \
      --sbin-path=/usr/sbin/nginx \
      --build=nginx-${NGINX_VER}-${DT}-enginescript \
      --builddir=nginx-${NGINX_VER} \
      --with-cc-opt="$CPU_SPECIFIC_FLAGS -DTCP_FASTOPEN=23 -O3 -fcode-hoisting -flto=auto -fPIC -fstack-protector-strong $LD_FLAG -Werror=format-security -Wformat -Wimplicit-fallthrough=0 -Wno-error=pointer-sign -Wno-implicit-function-declaration -Wno-int-conversion -Wno-cast-function-type -Wno-deprecated-declarations -Wno-error=date-time -Wno-error=strict-aliasing -Wno-format-extra-args --param=ssp-buffer-size=4" \
      --with-ld-opt="-Wl,-z,relro -Wl,-z,now -Wl,-s -fPIC -flto=auto $LD_FLAG" \
      --with-openssl-opt="enable-ec_nistp_64_gcc_128 enable-ktls enable-tls1_2 enable-tls1_3 no-ssl3-method no-tls1-method no-tls1_1-method no-weak-ssl-ciphers zlib -fPIC -march=native --release" \
      --with-openssl=/usr/src/openssl-${OPENSSL_VER} \
      --with-libatomic \
      --with-file-aio \
      --with-threads \
      --with-pcre=/usr/src/pcre2-${PCRE2_VER} \
      --with-pcre-jit \
      --with-zlib=/usr/src/zlib-cf \
      --with-zlib-opt=-fPIC \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_v3_module \
      --with-http_realip_module \
      --add-module=/usr/src/headers-more-nginx-module-${NGINX_HEADER_VER} \
      --add-module=/usr/src/ngx_brotli \
      --add-module=/usr/src/ngx_cache_purge-${NGINX_PURGE_VER} \
      --without-http_browser_module \
      --without-http_empty_gif_module \
      --without-http_memcached_module \
      --without-http_scgi_module \
      --without-http_split_clients_module \
      --without-http_userid_module \
      --without-http_uwsgi_module \
      --without-mail_imap_module \
      --without-mail_pop3_module \
      --without-mail_smtp_module

  else
    # HTTP2
    ./configure \
      --prefix=/etc/nginx \
      --conf-path=/etc/nginx/nginx.conf \
      --user=www-data \
      --group=www-data \
      --error-log-path=/var/log/nginx/nginx.error.log \
      --http-client-body-temp-path=/var/lib/nginx/body \
      --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
      --http-log-path=/var/log/nginx/nginx.access.log \
      --http-proxy-temp-path=/var/lib/nginx/proxy \
      --lock-path=/run/lock/nginx.lock \
      --modules-path=/etc/nginx/modules \
      --pid-path=/run/nginx.pid \
      --sbin-path=/usr/sbin/nginx \
      --build=nginx-${NGINX_VER}-${DT}-enginescript \
      --builddir=nginx-${NGINX_VER} \
      --with-cc-opt="$CPU_SPECIFIC_FLAGS -DTCP_FASTOPEN=23 -O3 -fcode-hoisting -flto=auto -fPIC -fstack-protector-strong $LD_FLAG -Werror=format-security -Wformat -Wimplicit-fallthrough=0 -Wno-error=pointer-sign -Wno-implicit-function-declaration -Wno-int-conversion -Wno-cast-function-type -Wno-deprecated-declarations -Wno-error=date-time -Wno-error=strict-aliasing -Wno-format-extra-args --param=ssp-buffer-size=4" \
      --with-ld-opt="-Wl,-z,relro -Wl,-z,now -Wl,-s -fPIC -flto=auto $LD_FLAG" \
      --with-openssl-opt="enable-ec_nistp_64_gcc_128 enable-ktls enable-tls1_2 enable-tls1_3 no-ssl3-method no-tls1-method no-tls1_1-method no-weak-ssl-ciphers zlib -fPIC -march=native --release" \
      --with-openssl=/usr/src/openssl-${OPENSSL_VER} \
      --with-libatomic \
      --with-file-aio \
      --with-threads \
      --with-pcre=/usr/src/pcre2-${PCRE2_VER} \
      --with-pcre-jit \
      --with-zlib=/usr/src/zlib-cf \
      --with-zlib-opt=-fPIC \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --add-module=/usr/src/headers-more-nginx-module-${NGINX_HEADER_VER} \
      --add-module=/usr/src/ngx_brotli \
      --add-module=/usr/src/ngx_cache_purge-${NGINX_PURGE_VER} \
      --without-http_browser_module \
      --without-http_empty_gif_module \
      --without-http_memcached_module \
      --without-http_scgi_module \
      --without-http_split_clients_module \
      --without-http_userid_module \
      --without-http_uwsgi_module \
      --without-mail_imap_module \
      --without-mail_pop3_module \
      --without-mail_smtp_module

fi

make -j"${CPU_COUNT}"
find "/usr/src/nginx-${NGINX_VER}" | xargs file | grep ELF | cut -f 1 -d : | xargs strip --strip-unneeded
make install

# Remove .default Files
rm -rf /etc/nginx/{*.default,*.dpkg-dist}

# Remove debug symbols
strip -s /usr/sbin/nginx*

checksec --format=json --file="/usr/sbin/nginx" --extended | jq -r

# Return to /usr/src
cd /usr/src
