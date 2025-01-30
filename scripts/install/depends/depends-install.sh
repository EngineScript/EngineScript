#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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

# Define the packages to install
packages="advancecomp apt-listchanges apt-show-versions apt-transport-https apt-utils aptitude autoconf autoconf-archive autogen automake autotools-dev axel bash bash-completion bc binutils bison brotli build-essential ccache ccze checkinstall checksec cmake colordiff cron curl debconf-utils debhelper dialog dmidecode dnsutils duf expat findutils freebsd-manpages geoipupdate gettext ghostscript gifsicle gzip htop hurl iotop imagemagick inotify-tools jpegoptim ktls-utils libpam-cgfs libatomic-ops-dev libatomic1 libbsd-dev libbz2-dev libbz2-ocaml libbz2-ocaml-dev libc6-dev libcunit1-dev libcurl4-openssl-dev libelf-dev libev-dev libevent-dev libexpat-dev libgc1 libgd-dev libgeoip-dev libgmp-dev libgoogle-perftools-dev libimage-exiftool-perl libjansson-dev libjemalloc-dev libjemalloc2 libjpeg-progs libmaxminddb-dev libmcrypt-dev libmcrypt4 libmhash-dev libmnl-dev libopts25-dev libpam0g-dev libpcre2-dev libpcre3 libpcre3-dev libperl-dev librabbitmq4 libreadline-dev libsodium-dev libssh2-1-dev libssl-dev libtidy-dev libtool libxml2 libxml2-dev libxslt1-dev lm-sensors logtail lsb-release lsof make mc mcrypt moreutils ncdu net-tools netcat-traditional nload nmon openssl optipng perl pigz pkg-config plocate pngcrush pngquant po-debconf procps python3-packaging re2c rlwrap rsync ruby-dev sed socat sockstat sysstat tar tree ubuntu-minimal ufw unzip update-manager-core uuid-dev vnstat webp wget whois yara zip zlib1g zlib1g-dev zstd"

# Install the packages with error checking
apt install -qy $packages || {
  echo "Error: Unable to install one or more packages. Exiting..."
  exit 1
}

# Nano
update-alternatives --set editor /bin/nano

# Cheat.sh
#curl https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh
#chmod +x /usr/local/bin/cht.sh
