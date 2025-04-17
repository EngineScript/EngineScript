# EngineScript

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/b8b03bc4beba44a7aee2f879029b2e95)](https://app.codacy.com/gh/EngineScript/EngineScript/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

## A High-Performance WordPress Server Built on Ubuntu and Cloudflare

EngineScript automates the process of building a high-performance LEMP server. We've specifically built EngineScript with WordPress users in mind, so the install process will take you from a bare server all the way to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript Release Stage: **Beta**

## Minimum Requirements

EngineScript is meant to be run as the root user on a fresh VPS. Setup will remove existing Apache, Nginx, PHP, and MySQL installations. Things **will** break if you run this script on a VPS that has already been configured.

- **A Newly Created VPS** *([Digital Ocean](https://m.do.co/c/e57cc8492285) droplet recommended)*
- **Ubuntu 24.04 (64-Bit)** *(Ubuntu 22.04 is also supported but is not recommended)*
- **2GB RAM**
- **Cloudflare** *(Free or Paid)*

----------

## Default Configuration ##

The default EngineScript configuration utilizes the simplified stack below. Additional information on specific software versions and sources can be found further down.

|||||
|-|-|-|-|
|**CDN \ SSL:** Cloudflare|||**Web Server:** Nginx|
|**Script Processing:** PHP|||**MySQL Database:** MariaDB|
|**Object Cache:** Redis|||**CMS:** WordPress|

----------

## Install EngineScript

### Step 1 - Initial Install

Run the following command:
```shell
wget https://raw.githubusercontent.com/EngineScript/EngineScript/master/setup.sh && bash setup.sh
```

### Step 2 - Edit Options File

After the initial setup script has run, you'll need to alter the install options file. Fill this out completely, making sure to change all variables that say `PLACEHOLDER`.

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

After EngineScript is fully installed, type `es.menu` in console to bring up the EngineScript menu. Choose **1) Domain Configuration Tools**, then select **1) Create New Domain** or **2) Import Domain** to get started adding your first site to the server. If you're moving an existing site into EngineScript, the Import Domain function is fairly robust and should help simplify the process quite a bit.

### Cloudflare

Before your site is ready to use, you'll need to go into Cloudflare to configure a number of important settings. Follow the steps below to configure Cloudflare for your domain.

#### Go to the Cloudflare Dashboard

1. Select your domain

#### DNS Tab

##### Records Section

First, we need to add a new CNAME record for admin.*YOURDOMAIN*. This will allow you to access the admin subdomain on your site. If you prefer, the admin control panel may also be accessed via IP address instead.

1. Click **Add record** button
2. **Type:** CNAME | **Name:** admin | **Target:** *your domain*

#### SSL/TLS Tab

##### Edge Certificates Section

1. Always Use HTTPS: **Off** - *(Important: This can cause redirect loops)*
2. HSTS: **On** - *(Optional)*
3. Minimum TLS Version: **TLS 1.2**
4. Opportunistic Encryption: **On**
5. TLS 1.3: **On**
6. Automatic HTTPS Rewrites: **On**
7. Certificate Transparency Monitoring: **Optional**

##### Origin Server Section

1. Authenticated Origin Pulls: **On**

#### Speed Tab

##### Optimization Section

Go through each optimization tab and select the following:

1. Speed Brain: **On**
2. Cloudflare Fonts **On**
3. Early Hints: **On**
4. Rocket Loader: **Optional** - *When enabled, this will disable Cloudflare's compression from origin functionality. Rocket loader can also cause issues with some plugins.*
5. HTTP/2: **On**
6. HTTP/2 to Origin: **On**
7. HTTP/3 (with QUIC): **On** - *(Note: Cloudflare does not currently support HTTP/3 to Origin)*
8. Enhanced HTTP/2 Prioritization **On** - *(Only available if you have Cloudflare Pro)*
9. 0-RTT Connection Resumption: **On**
10. AMP Real URL: **Optional**

#### Caching Tab

##### Configuration Section

1. Caching Level: **Standard**
2. Browser Cache TTL: **Respect Existing Headers**
3. Crawler Hints: **On**
4. Always Online: **On**

##### Tiered Cache Section

1. Tiered Cache Topology: **Smart Tiered Caching Topology**

#### Network Tab

1. IPv6 Compatibility: **On**
2. WebSockets: **On**
3. Pseudo IPv4: **Add Header**
4. IP Geolocation: **On**
5. Network Error Logging: **On**
6. Onion Routing: **On**
7. gRPC: **On**

#### Brotli and Gzip from Origin

For Cloudflare to support compression from origin, the following features must be disabled:

* Email Obfuscation
* Rocket Loader
* Server Side Excludes (SSE)
* Mirage
* HTML Minification (JavaScript and CSS can remain enabled)
* Automatic HTTPS Rewrites

For more information, see [This is Brotli from Origin](https://blog.cloudflare.com/this-is-brotli-from-origin/).

### WordPress Plugins

#### Nginx Helper

1. In WordPress, go to Settings >> Nginx Helper
2. Check Enable Purge.
3. Select "nginx Fastcgi cache" for Caching Method
4. Select "Using a GET request to PURGE/url (Default option)" for Purging Method.
5. Check all of the boxes under Purging Conditions.
6. Save Changes.

#### Other Plugins

EngineScript installs a number of additional plugins when a domain is added to the server. These plugins are purely optional, but may add some valuable functionality to your site. We only enable plugins that are required, so please take a moment to review all of the plugins to see if there is anything else you'd like to enable.

We've also developed a basic plugin that disables some bloat from the default WordPress experience such as TinyMCE emojis, Jetpack advertisements, and some legacy CSS from widgets and classic themes. There could be some edge-case scenarios where this breaks something specific you're using, but these tweaks are pretty safe for most users.

----------

## Sponsors:

EngineScript development is supported by:

Want to support EngineScript? [Sponsor this project](https://github.com/sponsors/EngineScript).

----------

## EngineScript Information Reference

### EngineScript Locations

|Location|Usage|
|-|-|
|**/etc/mysql**                  |MySQL (MariaDB) config |
|**/etc/nginx**                  |Nginx config |
|**/etc/php**                    |PHP config |
|**/etc/redis**                  |Redis config |
|**/home/EngineScript**          |EngineScript user directories |
|**/usr/local/bin/enginescript** |EngineScript source |
|**/var/lib/mysql**              |MySQL database |
|**/var/log**                    |Server logs |
|**/var/www/admin/enginescript** |Tools that may be accessed via server IP address or admin.YOURDOMAIN subdomain |
|**/var/www/sites/*YOURDOMAIN*/html** |Root directory for your WordPress installation |

### EngineScript Commands

|Command|Function|
|-|-|
|**`es.backup`**     |Runs the backup script to backup all domains locally and *optionally* in the cloud |
|**`es.cache`**      |Clear FastCGI Cache, OpCache, and Redis *(server-wide)* |
|**`es.config`**     |Opens the configuration file in Nano |
|**`es.debug`**      |Displays debug information for EngineScript |
|**`es.help`**       |Displays EngineScript commands and locations |
|**`es.images`**     |Losslessly compress all images in the WordPress /uploads directory *(server-wide)* |
|**`es.info`**       |Displays server information |
|**`es.install`**    |Runs the main EngineScript installation script |
|**`es.menu`**       |EngineScript menu |
|**`es.permissions`** |Resets the permissions of all files in the WordPress directory *(server-wide)* |
|**`es.restart`**    |Restart Nginx and PHP |
|**`es.update`**     |Update EngineScript |
|**`es.variables`**  |Opens the variable file in Nano. This file resets when EngineScript is updated |

### Software EngineScript Utilizes:

|Software|Version|Source|
|-|-|-|
| 	**Certificate Management**		|
|ACME.sh|Latest|https://get.acme.sh |
||
||
|**Web Server**|
|NGINX MAINLINE|1.27.4|https://nginx.org/en/download.html |
|NGINX CACHE PURGE|2.5.3|https://github.com/nginx-modules/ngx_cache_purge |
|NGINX HEADERS MORE|0.38|https://github.com/openresty/headers-more-nginx-module |
|NGINX PATCH: Dynamic TLS Records|Latest |https://github.com/kn007/patch|
|OPENSSL|3.4.1|https://www.openssl.org/source/ |
|PCRE2|10.45|https://github.com/PCRE2Project/pcre2/releases |
|ZLIB-Cloudflare|Latest|https://github.com/cloudflare/zlib |
||
||
|**Script Processing**|
|PHP|8.3|https://launchpad.net/~ondrej/+archive/ubuntu/php |
||
||
|**MySQL Database**|
|MARIADB|11.4.5|https://mariadb.org/download/ |
||
||
|**Database Management**|
|ADMINER|||
|PHPMYADMIN|5.2.2|https://www.phpmyadmin.net/downloads/ |
||
||
|**Object Cache**|
|REDIS|Latest|https://redis.io/ |
||
||
|**Content Management System (CMS)**|
|WORDPRESS | Latest |https://wordpress.org |
|WP-CLI | Latest |https://github.com/wp-cli/wp-cli |
|WP-CLI: doctor-command | Latest |https://github.com/wp-cli/doctor-command |
|WP-CLI: WP Launch Check | Latest |https://github.com/pantheon-systems/wp_launch_check |
|PLUGIN: App for Cloudflare| Latest |https://wordpress.org/plugins/app-for-cf/ |
|PLUGIN: EngineScript: Simple Site Exporter| 1.3.3 | [https://github.com/EngineScript/EngineScript](https://github.com/EngineScript/EngineScript/blob/master/config/var/www/wordpress/plugins/simple-site-exporter-enginescript/simple-site-exporter.php) |
|PLUGIN: EngineScript: WP Optimization| 1.4.1 | [https://github.com/EngineScript/EngineScript](https://github.com/EngineScript/EngineScript/blob/master/config/var/www/wordpress/plugins/simple-wp-optimizer-enginescript/simple-wp-optimizer.php) |
|PLUGIN: MariaDB Health Checks *(recommended)* | Latest |https://wordpress.org/plugins/mariadb-health-checks/ |
|PLUGIN: Nginx Helper *(required)* | Latest |https://wordpress.org/plugins/nginx-helper/ |
|PLUGIN: PHP Compatibility Checker| Latest |https://wordpress.org/plugins/php-compatibility-checker/ |
|PLUGIN: Redis Object Cache *(recommended)*| Latest |https://wordpress.org/plugins/redis-cache/ |
|PLUGIN: The SEO Framework *(recommended)*| Latest |https://wordpress.org/plugins/autodescription/ |
|PLUGIN: Theme Check| Latest |https://wordpress.org/plugins/theme-check/ |
|PLUGIN: WP Crontrol| Latest |https://wordpress.org/plugins/wp-crontrol/ |
|PLUGIN: WP Mail SMTP| Latest |https://wordpress.org/plugins/wp-mail-smtp/ |
|PLUGIN: WP OPcache *(recommended)*| Latest | https://wordpress.org/plugins/flush-opcache/ |
||
||
|**Security**|
|MALDETECT|Latest|https://www.rfxn.com/projects/linux-malware-detect/ |
|PHP-MALWARE-FINDER|Latest|https://github.com/nbs-system/php-malware-finder |
|UNCOMPLICATED FIREWALL (UFW) || Bundled with Ubuntu |
|WORDFENCE CLI||https://github.com/wordfence/wordfence-cli/releases |
|WPSCAN|Latest|https://wpscan.com/ |
||
||
|**Development Tools**|
|PNGOUT|20200115|http://www.jonof.id.au/kenutils.html |
|ZIMAGEOPTIMIZER|Latest|https://github.com/zevilz/zImageOptimizer |
||
||
|**Backup Software**|
|LOCAL BACKUPS|| Bash Scripts |
|AMAZON AWS CLI|Latest|https://aws.amazon.com/cli/ |
||
||
|**Misc Supplemental Software**|
|LIBURING|2.9|https://github.com/axboe/liburing |
|MYSQLTUNER|Latest|https://github.com/major/MySQLTuner-perl |
|ZLIB|1.3.1|https://github.com/madler/zlib |
|Admin Control Panel Template|-|https://github.com/bhjoco/onepage-medium |

----------
