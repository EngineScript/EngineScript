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
#
# Build and install Nginx from source, for both the install (nginx-install.sh) and the update
# (nginx-update.sh): download Nginx and its modules, fetch the OpenSSL, zlib, and PCRE2 sources
# it compiles in (the versions in enginescript-variables.txt), compile, and make install.
# The first step that fails stops the build with exit 1. make install replaces /usr/sbin/nginx
# (keeping the previous binary as nginx.old); a caller that keeps a backup restores it when the
# build fails.

run_step "Nginx Source Downloads" /usr/local/bin/enginescript/scripts/install/nginx/nginx-download.sh || die "The Nginx source download failed."
run_step "Brotli" /usr/local/bin/enginescript/scripts/install/nginx/nginx-brotli.sh || die "The Brotli module could not be downloaded or built."
run_step "OpenSSL" /usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh || die "The OpenSSL source download failed."
run_step "zlib" /usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh || die "The zlib source download failed."
run_step "PCRE2" /usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh || die "The PCRE2 source download failed."
run_step "Compile Nginx" /usr/local/bin/enginescript/scripts/install/nginx/nginx-compile.sh || die "Nginx failed to compile."
