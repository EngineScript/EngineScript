#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# PCRE
cd /usr/src
wget https://github.com/PhilipHazel/pcre2/releases/download/pcre2-${PCRE2_VER}/pcre2-${PCRE2_VER}.tar.gz && tar xzvf pcre2-${PCRE2_VER}.tar.gz --no-check-certificate

# Uncomment below if you want to use the latest PCRE for the entire server.
# Not guaranteed to work properly.

#cd /usr/src/pcre2-${PCRE2_VER}
#./configure \
#  --prefix=/usr \
#  --enable-utf8 \
#  --enable-unicode-properties \
#  --enable-pcre16 \
#  --enable-pcre32 \
#  --enable-pcregrep-libz \
#  --enable-pcregrep-libbz2 \
#  --enable-pcretest-libreadline \
#  --enable-jit

#make -j${CPU_COUNT}
#make test
#make install
#mv -v /usr/lib/libpcre.so.* /lib
#ln -sfv ../../lib/$(readlink /usr/lib/libpcre.so) /usr/lib/libpcre.so
#ldconfig
