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

# Install Dependencies
apt update && apt upgrade -y

apt install -qy advancecomp apt-listchanges apt-show-versions apt-transport-https apt-utils autoconf autoconf-archive autogen automake autotools-dev axel bash bash-completion bc binutils bison brotli build-essential ccache ccze checkinstall cmake colordiff curl debhelper dh-systemd dialog dmidecode expat findutils g++-10 g++-9 g++-9-multilib gcc-10 gcc-9 geoipupdate gettext ghostscript gifsicle glances guile-2.0-libs gzip htop imagemagick jpegoptim libatomic-ops-dev libatomic1 libbsd-dev libbz2-1.0 libbz2-dev libbz2-ocaml libbz2-ocaml-dev libc6-dev libcunit1-dev libcurl4-openssl-dev libelf-dev libev-dev libevent-dev libexpat-dev libgc1c2 libgd-dev libgeoip-dev libgmp-dev libgoogle-perftools-dev libimage-exiftool-perl libjansson-dev libjemalloc-dev libjemalloc2 libjpeg-progs libluajit-5.1-2 libluajit-5.1-common libluajit-5.1-dev libmaxminddb-dev libmcrypt-dev libmcrypt4 libmhash-dev libmnl-dev libopts25-dev libpam0g-dev libpcre2-dev libpcre3 libpcre3-dev libperl-dev librabbitmq4 libreadline-dev libssh2-1-dev libssl-dev libtidy-dev libtool libxml2 libxml2-dev libxslt1-dev lm-sensors logtail lsb-release lsof make mc mcrypt mlocate moreutils net-tools netcat nload nmon openssl optipng perl pigz pkg-config pngcrush pngquant po-debconf python3-apt python3-jinja2 python3-markupsafe python3-pip python3-psutil python3-pyasn1 python3-requests python3-setuptools re2c rlwrap rsync ruby-dev sed socat tar tree ubuntu-minimal ufw unzip uuid-dev webp wget whois yara zip zlib1g zlib1g-dev zlibc zstd

# Nano
update-alternatives --set editor /bin/nano
curl https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh

# Cheat.sh
#curl https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh
#chmod +x /usr/local/bin/cht.sh

systemctl daemon-reload
