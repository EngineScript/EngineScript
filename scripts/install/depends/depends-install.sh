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

# Update & Upgrade, which also reads the repositories the Repositories step added
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh || exit 1

# The packages to install, grouped by what uses them. Each one needs a reason to be here: a
# package nothing uses still costs disk space, update time, and sometimes a service or timer.
# The packages below exist on every supported Ubuntu release; the ones that exist only on some
# releases are added after the list. One missing package stops the whole install.
#
# No development libraries (-dev) beyond the ones below: Nginx compiles with its own copies of
# OpenSSL, PCRE2, zlib, and Brotli, and PHP comes from packages. Runtime libraries come in as
# dependencies of the packages that use them.
packages=(
  # Base system and package management
  "apt-listchanges"     # shows what changed in a package before it is upgraded
  "apt-show-versions"   # which packages have upgrades, and from which repository
  "apt-transport-https"
  "apt-utils"
  "aptitude"
  "bash"
  "bash-completion"
  "ca-certificates"
  "debconf-utils"
  "dialog"              # debconf's interactive prompts
  "findutils"
  "logrotate"
  "lsb-release"
  "procps"
  "ubuntu-minimal"
  "update-manager-core" # do-release-upgrade

  # Compiling Nginx, OpenSSL, and Brotli (the install and every Nginx update)
  "binutils"
  "build-essential"
  "cmake"               # Brotli
  "libatomic-ops-dev"   # Nginx's --with-libatomic
  "libatomic1"
  "libc6-dev"
  "make"
  "perl"                # OpenSSL's Configure
  "pkg-config"
  "zlib1g"

  # Build tools for compiling other software on the server. EngineScript's own builds do not use
  # them; they are here for the admin's own compiles.
  "autoconf"
  "autoconf-archive"
  "automake"
  "autotools-dev"
  "bison"
  "ccache"
  "checkinstall"        # turns "make install" into a package that can be removed
  "libtool"
  "re2c"

  # Kept for later use
  "geoipupdate"         # MaxMind's GeoIP database download; /etc/GeoIP.conf needs an account first
  "yara"                # malware rules; Maldet can scan with them

  # WPScan: its gems compile against Ruby's headers
  "libgmp-dev"          # needed by ruby-dev
  "ruby-dev"

  # WordPress media: PHP's Imagick, and PDF thumbnails through Ghostscript
  "ghostscript"
  "imagemagick"

  # Image optimization: zImageOptimizer and the image metadata cron
  "advancecomp"
  "bc"
  "gifsicle"
  "jpegoptim"
  "libimage-exiftool-perl" # exiftool
  "libjpeg-progs"
  "optipng"
  "pngcrush"
  "pngquant"
  "webp"

  # Security
  "checksec"            # Security Tools menu
  "ufw"
  "whois"               # whois and mkpasswd; fail2ban recommends it for looking up banned addresses

  # Monitoring and diagnostics: EngineScript's menus and es.debug use the first six
  "dnsutils"            # dig, host
  "fio"                 # disk benchmark
  "htop"
  "iotop"
  "ncdu"
  "net-tools"           # netstat, route
  "vnstat"
  "dmidecode"
  "duf"
  "inotify-tools"
  "lm-sensors"
  "logtail"
  "lsof"
  "nload"
  "nmon"
  "sockstat"
  "sysstat"             # sar: CPU, memory, and disk history

  # Command-line tools for the server's admin
  "brotli"
  "ccze"
  "colordiff"
  "expat"
  "gettext"
  "hurl"                # HTTP request testing
  "jq"                  # also used by EngineScript's scripts
  "mc"
  "moreutils"
  "pigz"
  "rlwrap"
  "rsync"               # also used by Import Domain
  "socat"               # also needed by MariaDB
  "tree"
  "zstd"
)

# Packages that exist only on some releases:
# - wtmpdb: Ubuntu 26.04 records logins with wtmpdb, which provides the "last" command (on 24.04
#   util-linux provides it); Security Tools > Login History uses it
case "${UBUNTU_VERSION}" in
  26.04) packages+=("wtmpdb") ;;
esac

# Install the packages with error checking
apt-get install -qy "${packages[@]}" || {
  echo "Error: Unable to install one or more packages. Exiting..."
  exit 1
}

# Nano
update-alternatives --set editor /bin/nano

echo "Install Dependencies completed successfully. Script done."
