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

source /etc/enginescript/install-state.conf
if [[ "${DEPENDS}" = 1 ]]; then
    echo "DEPENDS script has already run"
    exit 0
fi

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

# Define the packages to install
packages=(
    "advancecomp"
    "apt-listchanges"
    "apt-show-versions"
    "apt-transport-https"
    "apt-utils"
    "aptitude"
    "autoconf"
    "autoconf-archive"
    "autogen"
    "automake"
    "autotools-dev"
    "axel"
    "bash"
    "bash-completion"
    "bc"
    "binutils"
    "bison"
    "brotli"
    "build-essential"
    "ca-certificates"
    "ccache"
    "ccze"
    "checkinstall"
    "checksec"
    "cmake"
    "colordiff"
    "debconf-utils"
    "debhelper"
    "dialog"
    "dmidecode"
    "dnsutils"
    "duf"
    "expat"
    "findutils"
    "fio"
    "geoipupdate"
    "gettext"
    "ghostscript"
    "gifsicle"
    "htop"
    "hurl"
    "iotop"
    "imagemagick"
    "inotify-tools"
    "jpegoptim"
    "ktls-utils"
    "libpam-cgfs"
    "libatomic-ops-dev"
    "libatomic1"
    "libbsd-dev"
    "libbz2-dev"
    "libbz2-ocaml"
    "libbz2-ocaml-dev"
    "libc6-dev"
    "libcunit1-dev"
    "libcurl4-openssl-dev"
    "libelf-dev"
    "libev-dev"
    "libevent-dev"
    "libexpat-dev"
    "libgc1"
    "libgd-dev"
    "libgeoip-dev"
    "libgmp-dev"
    "libgoogle-perftools-dev"
    "libimage-exiftool-perl"
    "libjansson-dev"
    "libjemalloc-dev"
    "libjemalloc2"
    "libjpeg-progs"
    "libmaxminddb-dev"
    "libmcrypt-dev"
    "libmcrypt4"
    "libmhash-dev"
    "libmnl-dev"
    "libopts25-dev"
    "libpam0g-dev"
    "libpcre2-dev"
    "libpcre3"
    "libpcre3-dev"
    "libperl-dev"
    "librabbitmq4"
    "libreadline-dev"
    "libsodium-dev"
    "libssh2-1-dev"
    "libssl-dev"
    "libtidy-dev"
    "libtool"
    "libxml2"
    "libxml2-dev"
    "libxslt1-dev"
    "lm-sensors"
    "logrotate"
    "logtail"
    "lsb-release"
    "lsof"
    "make"
    "mc"
    "mcrypt"
    "moreutils"
    "ncdu"
    "net-tools"
    "netcat-traditional"
    "nload"
    "nmon"
    "optipng"
    "perl"
    "pigz"
    "pkg-config"
    "plocate"
    "pngcrush"
    "pngquant"
    "po-debconf"
    "procps"
    "re2c"
    "rlwrap"
    "rsync"
    "ruby-dev"
    "socat"
    "sockstat"
    "sysstat"
    "tree"
    "ubuntu-minimal"
    "ufw"
    "update-manager-core"
    "uuid-dev"
    "vnstat"
    "webp"
    "whois"
    "yara"
    "zlib1g"
    "zlib1g-dev"
    "zstd"
)

# Install the packages with error checking
apt install -qy "${packages[@]}" || {
  echo "Error: Unable to install one or more packages. Exiting..."
  exit 1
}

# Nano
update-alternatives --set editor /bin/nano

# Mark the installation as complete
echo "DEPENDS=1" >> /etc/enginescript/install-state.conf
