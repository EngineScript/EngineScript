# EngineScript

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/b8b03bc4beba44a7aee2f879029b2e95)](https://app.codacy.com/gh/EngineScript/EngineScript/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![GPL License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Nginx Mainline](https://img.shields.io/badge/Nginx-Mainline-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?logo=php&logoColor=white)](https://www.php.net/)
[![MariaDB](https://img.shields.io/badge/MariaDB-11.8-003545?logo=mariadb&logoColor=white)](https://mariadb.org/)
[![Redis](https://img.shields.io/badge/Redis-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-0080FF?logo=digitalocean&logoColor=white)](https://m.do.co/c/e57cc8492285)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?logo=cloudflare&logoColor=white)](https://cloudflare.com/)
[![WordPress](https://img.shields.io/badge/WordPress-21759B?logo=wordpress&logoColor=white)](https://wordpress.org/)
[![WP-CLI](https://img.shields.io/badge/WP--CLI-21759B?logo=wordpress&logoColor=white)](https://wp-cli.org/)
[![ACME.sh](https://img.shields.io/badge/ACME.sh-41BDF5?logo=letsencrypt&logoColor=white)](https://github.com/acmesh-official/acme.sh)
[![phpMyAdmin](https://img.shields.io/badge/phpMyAdmin-6C78AF?logo=phpmyadmin&logoColor=white)](https://www.phpmyadmin.net/)
[![AWS CLI](https://img.shields.io/badge/AWS_CLI-232F3E?logo=amazonwebservices&logoColor=white)](https://aws.amazon.com/cli/)

## A High-Performance WordPress Server Built on Ubuntu and Cloudflare

EngineScript automates the process of building a high-performance LEMP server. We built EngineScript with WordPress users in mind, so the install process takes you from a bare server to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript Release Stage: **Beta**

## Minimum Requirements

Run EngineScript as the root user on a fresh VPS. Setup removes existing Apache, Nginx, PHP, and MySQL installations. Existing services **will** break if you run this script on a VPS that already has software configured.

- **A Newly Created VPS** *([DigitalOcean](https://m.do.co/c/e57cc8492285) droplet recommended)*
- **Ubuntu 24.04 (64-bit)**
- **2 GB RAM**
- **Cloudflare** *(Free or Paid)*

----------

## Install EngineScript

### Step 1 - Initial Install

Run the following command:

```shell
bash <(curl -s https://raw.githubusercontent.com/EngineScript/EngineScript/master/setup.sh)
```

### Step 2 - Edit Options File

After the initial setup script runs, update the install options file. Replace every `PLACEHOLDER` value before continuing.

Run the following command:

```shell
es.config
```

### Step 3 - Main Install Process

Once you've filled out the configuration file with your personal settings, continue with the main installation process.

Run the following command:

```shell
es.install
```

----------

## Domain Creation

### EngineScript Menu

After EngineScript is fully installed, type `es.menu` at the console to open the EngineScript menu. Choose **1) Domain Configuration Tools**, then select **1) Create New Domain** or **2) Import Domain** to add your first site to the server. If you're moving an existing site into EngineScript, the Import Domain function helps simplify the process.

### Cloudflare

Before your site is ready to use, add it to Cloudflare. The scripts that add or import a domain automatically add or update Cloudflare DNS records to point to your server, issue SSL certificates, and apply several performance-related Cloudflare settings.

For reference, see the settings EngineScript automatically applies in the [Cloudflare Settings Guide](https://github.com/EngineScript/EngineScript/wiki/Cloudflare-Settings).

### Manual Cloudflare Settings

Although we do our best to automate this process, there are a few settings that we do not currently change through the Cloudflare API. We recommend enabling the following settings manually in Cloudflare:

1. Speed Tab: **Cloudflare Fonts**: **On**
2. Caching Tab: **Crawler Hints**: **On**
3. Network Tab: **HTTP Strict Transport Security (HSTS)**: **On**

#### Brotli and Gzip from Origin

For Cloudflare to support compression from origin, the following features must be disabled:

- Email Obfuscation
- Rocket Loader
- Server-Side Excludes (SSE)
- Mirage
- HTML Minification (JavaScript and CSS can remain enabled)
- Automatic HTTPS Rewrites

For more information, see [This is Brotli from Origin](https://blog.cloudflare.com/this-is-brotli-from-origin/).

### WordPress Plugins

#### Nginx Helper

1. In WordPress, go to Settings >> Nginx Helper
2. Check Enable Purge.
3. Select "nginx FastCGI cache" for Caching Method
4. Select "Using a GET request to PURGE/url (Default option)" for Purging Method.
5. Check every box under Purging Conditions.
6. Save Changes.

#### Other Plugins

EngineScript installs plugins when a domain is added to the server. These plugins are optional, but they may add useful functionality to your site. Required plugins are enabled automatically, so review the installed plugins to see if there is anything else you'd like to enable.

We also developed a basic plugin that disables some bloat from the default WordPress experience, such as TinyMCE emojis, Jetpack advertisements, and legacy CSS from widgets and classic themes. These tweaks are safe for most users, but there may be edge cases where they affect something specific to your site.

----------

## Sponsors

EngineScript development is supported by:

Want to support EngineScript? [Sponsor this project](https://github.com/sponsors/EngineScript).

----------

## EngineScript Information Reference

### EngineScript Locations

|Location|Usage|
|-|-|
|**/etc/mysql**|MySQL (MariaDB) config|
|**/etc/nginx**|Nginx config|
|**/etc/php**|PHP config|
|**/etc/redis**|Redis config|
|**/home/EngineScript**|EngineScript user directories|
|**/usr/local/bin/enginescript**|EngineScript source|
|**/var/lib/mysql**|MySQL database|
|**/var/log**|Server logs|
|**/var/www/admin/control-panel**|EngineScript Admin Dashboard|
|**/var/www/admin/tools**|Admin tools (phpMyAdmin, TinyFileManager, phpSysInfo, Adminer)|
|**/var/www/sites/*YOURDOMAIN*/html**|Root directory for your WordPress installation|

### EngineScript Commands

|Command|Function|
|-|-|
|**`es.backup`**|Runs the backup script to back up all domains locally and *optionally* in the cloud|
|**`es.cache`**|Clears FastCGI cache, OPcache, and Redis *(server-wide)*|
|**`es.config`**|Opens the configuration file in Nano|
|**`es.debug`**|Displays debug information for EngineScript|
|**`es.help`**|Displays EngineScript commands and locations|
|**`es.images`**|Losslessly compress all images in the WordPress /uploads directory *(server-wide)*|
|**`es.info`**|Displays server information|
|**`es.install`**|Runs the main EngineScript install script|
|**`es.menu`**|EngineScript menu|
|**`es.permissions`**|Resets the permissions of all files in the WordPress directory *(server-wide)*|
|**`es.restart`**|Restarts Nginx and PHP|
|**`es.sites`**|Lists all WordPress sites installed on the server with status information|
|**`es.update`**|Updates EngineScript|
|**`es.variables`**|Opens the variable file in Nano. This file resets when EngineScript is updated|

### Admin Control Panel Features

EngineScript includes a comprehensive web-based admin control panel accessible at `https://admin.yourdomain.com`. The control panel provides:

- Server monitoring and management tools
- Uptime monitoring and reporting for all WordPress sites
- Web-based file management with Tiny File Manager
- Quick access to common server management tasks and tools

### Software EngineScript Utilizes

|Software|Version|Source|
|-|-|-|
|**Certificate Management**|||
|ACME.sh||<https://get.acme.sh>|
|**Web Server**|||
|NGINX MAINLINE|1.31.5|<https://nginx.org/en/download.html>|
|NGINX CACHE PURGE|3.0.2|<https://github.com/nginx-modules/ngx_cache_purge>|
|NGINX HEADERS MORE|0.40|<https://github.com/openresty/headers-more-nginx-module>|
|NGINX PATCH: Dynamic TLS Records|Latest|<https://github.com/nginx-modules/ngx_http_tls_dyn_size>|
|OPENSSL|3.5.8|<https://www.openssl.org/source/>|
|PCRE2|10.48|<https://github.com/PCRE2Project/pcre2/releases>|
|ZLIB|1.3.2|<https://github.com/madler/zlib>|
|**Application Server**|||
|PHP|8.5|<https://launchpad.net/~ondrej/+archive/ubuntu/php>|
|**Database Server**|||
|MARIADB|11.8.6|<https://mariadb.org/download/>|
|**Object Cache**|||
|REDIS||<https://redis.io/>|
|**Admin Control Panel**|||
|Font Awesome|7.0.1|<https://github.com/FortAwesome/Font-Awesome>|
|TinyFileManager|2.6|<https://github.com/prasathmani/tinyfilemanager>|
|**Database Management**|||
|ADMINER|||
|PHPMYADMIN|5.2.3|<https://www.phpmyadmin.net/downloads/>|
|**Content Management System (CMS)**|||
|WORDPRESS|Latest|<https://wordpress.org>|
|PLUGIN: Action Scheduler *(optional)*||<https://wordpress.org/plugins/action-scheduler/>|
|PLUGIN: EngineScript Site Exporter *(optional)*|2.1.0|[https://github.com/EngineScript/enginescript-site-exporter](https://github.com/EngineScript/enginescript-site-exporter)|
|PLUGIN: EngineScript Site Optimizer *(optional)*|2.1.0|[https://github.com/EngineScript/enginescript-site-optimizer](https://github.com/EngineScript/enginescript-site-optimizer)|
|PLUGIN: MariaDB Health Checks *(highly recommended)*||<https://wordpress.org/plugins/mariadb-health-checks/>|
|PLUGIN: Nginx Helper *(required)*||<https://wordpress.org/plugins/nginx-helper/>|
|PLUGIN: Performance Lab *(optional)*||<https://wordpress.org/plugins/performance-lab/>|
|PLUGIN: PHP Compatibility Checker *(optional)*||<https://wordpress.org/plugins/php-compatibility-checker/>|
|PLUGIN: Redis Object Cache *(supported and recommended)*||<https://wordpress.org/plugins/redis-cache/>|
|PLUGIN: The SEO Framework *(recommended)*||<https://wordpress.org/plugins/autodescription/>|
|PLUGIN: Theme Check *(optional)*||<https://wordpress.org/plugins/theme-check/>|
|PLUGIN: WP Crontrol *(optional)*||<https://wordpress.org/plugins/wp-crontrol/>|
|PLUGIN: WP Mail SMTP *(optional)*||<https://wordpress.org/plugins/wp-mail-smtp/>|
|PLUGIN: WP OPcache *(recommended)*||<https://wordpress.org/plugins/flush-opcache/>|
|WP-CLI||<https://github.com/wp-cli/wp-cli>|
|WP-CLI: doctor-command||<https://github.com/wp-cli/doctor-command>|
|WP-CLI: WP Launch Check||<https://github.com/pantheon-systems/wp_launch_check>|
|**Security**|||
|MALDETECT||<https://www.rfxn.com/projects/linux-malware-detect/>|
|UNCOMPLICATED FIREWALL (UFW)||Bundled with Ubuntu|
|WORDFENCE CLI||<https://github.com/wordfence/wordfence-cli/releases>|
|WPSCAN||<https://wpscan.com/>|
|**Development Tools**|||
|PNGOUT|20200115|<http://www.jonof.id.au/kenutils.html>|
|ZIMAGEOPTIMIZER||<https://github.com/zevilz/zImageOptimizer>|
|**Backup Software**|||
|LOCAL BACKUPS||Bash Scripts|
|AMAZON AWS CLI||<https://aws.amazon.com/cli/>|
|**Misc Supplemental Software**|||
|LIBURING|2.15|<https://github.com/axboe/liburing>|
|MYSQLTUNER||<https://github.com/major/MySQLTuner-perl>|

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=EngineScript/EngineScript&type=Date)](https://www.star-history.com/#EngineScript/EngineScript&Date)
