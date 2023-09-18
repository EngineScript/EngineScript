#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
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

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

apt install -qy advancecomp apt-listchanges apt-show-versions apt-transport-https apt-utils aptitude autoconf autoconf-archive autogen automake autotools-dev axel bash bash-completion bc binutils bison brotli build-essential ccache ccze checkinstall cmake colordiff curl debconf-utils debhelper dialog dmidecode dnsutils expat findutils g++-11 gcc-11 g++-12 gcc-12 geoipupdate gettext ghostscript gifsicle guile-3.0-libs gzip htop iotop imagemagick inotify-tools jpegoptim libpam-cgfs libatomic-ops-dev libatomic1 libbsd-dev libbz2-1.0 libbz2-dev libbz2-ocaml libbz2-ocaml-dev libc6-dev libcunit1-dev libcurl4-openssl-dev libelf-dev libev-dev libevent-dev libexpat-dev libgc1 libgd-dev libgeoip-dev libgmp-dev libgoogle-perftools-dev libimage-exiftool-perl libjansson-dev libjemalloc-dev libjemalloc2 libjpeg-progs libluajit-5.1-2 libluajit-5.1-common libluajit-5.1-dev libmaxminddb-dev libmcrypt-dev libmcrypt4 libmhash-dev libmnl-dev libopts25-dev libpam0g-dev libpcre2-dev libpcre3 libpcre3-dev libperl-dev librabbitmq4 libreadline-dev libsodium-dev libssh2-1-dev libssl-dev libtidy-dev libtool libxml2 libxml2-dev libxslt1-dev lm-sensors logtail lsb-release lsof make mc mcrypt mlocate moreutils ncdu net-tools netcat nload nmon openssl optipng perl pigz pkg-config pngcrush pngquant po-debconf re2c rlwrap rsync ruby-dev sed socat sysstat tar tree ubuntu-minimal ufw unzip update-manager-core uuid-dev vnstat webp wget whois yara zip zlib1g zlib1g-dev zstd

# Nano
update-alternatives --set editor /bin/nano

# Cheat.sh
#curl https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh
#chmod +x /usr/local/bin/cht.sh
