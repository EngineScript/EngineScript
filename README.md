# EngineScript

## A High-Performance WordPress Server Built on Ubuntu and Cloudflare

EngineScript automates the process of building a high-performance LEMP server. We've specifically built EngineScript with WordPress users in mind, so the install process will take you from a bare server all the way to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript is meant to be run as root user on a fresh VPS. Initial setup will remove existing Apache, Nginx, PHP, and MySQL installations, so be careful. Things will definitely break if you run this script on a VPS that has already been configured as a webserver.

As this is a pre-release version, things may be broken.

## Features
### Default EngineScript Configuration ###
The standard EngineScript configuration utilizes the simplified stack below. Additional information on specific software versions and sources can be found further down.

|Function        |Software    |
|----------------|------------|
|SSL Certificate Management | Cloudflare |
|CDN | Cloudflare |
|Web Server | Nginx | FastCGI Cache | OpenSSL | Cloudflare ZLib | Performance Patches |
|Script Processing | PHP | PHP OPCACHE |
|MySQL Database | MariaDB |
|Object Cache | Redis |
|CMS | WordPress |
|Firewall | UFW |

## Requirements
- **A Newly Created VPS** *([Digital Ocean](https://m.do.co/c/e57cc8492285) droplet recommended)*
- **Ubuntu 24.04 (64-Bit)** *(Ubuntu 22.04 is also supported but is not recommended)*
- **2GB RAM**
- **Cloudflare** *(free or paid)*
- **30 minutes of your time**

## Install EngineScript
### Step 1 - Initial Install
Run the following command:
```shell
wget https://raw.githubusercontent.com/EngineScript/EngineScript/master/setup.sh && bash setup.sh
```

### Step 2 - Edit Options File
After the initial setup script has run, you'll need to alter the install options file.

First, retrieve your Cloudflare Global API Key at **https://dash.cloudflare.com/profile/api-tokens**. Then you'll need to edit the configuration file at **/home/EngineScript/enginescript-install-options.txt**. Fill this out completely, making sure to change all variables that say `PLACEHOLDER`.

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
After EngineScript is fully installed, type `es.menu` in console to bring up the EngineScript menu. Choose option **1** to create a new domain.

Domain creation is almost entirely automated, requiring you to only enter the domain name you wish to create. During this automated process, we'll create a unique Nginx vhost file, create new MySQL database, request a new SSL certificate from Cloudflare, download WordPress, install and activate plugins, and assign the applicable data to your wp-config.php.

Before your site is ready to use, you'll need to go into Cloudflare to configure a number of important settings. Follow the steps below to finalize your installation:

### Cloudflare
#### Go to the Cloudflare Dashboard
1. Select your site

#### SSL/TLS Tab
##### Overview Section
1. Click **Configure** button
2. Under Custom SSL/TLS, click **Select** button
3. Set the SSL mode to **Full (Strict)**

##### Edge Certificates Section
1. Always Use HTTPS: **Off** *(Important: This can cause redirect loops)*
2. HSTS: **On** *(Optional)* We recommend enabling HSTS. However, turning off HSTS will make your site unreachable until the Max-Age time expires. This is a setting you want to set once and leave on forever.
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
4. Rocket Loaders: **Optional** *Test this on your site, it can cause issues with some plugins*
5. HTTP/2: **On**
6. HTTP/2 to Origin: **On**
7. HTTP/3 (with QUIC): **On** *Cloudflare does not currently support HTTP/3 to Origin
8. Enhanced HTTP/2 Prioritization **On** *Only available if you have Cloudflare Pro*
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

### WordPress Plugins
#### Nginx Helper
1. In WordPress, go to Settings >> Nginx Helper
2. Check Enable Purge.
3. Select "nginx Fastcgi cache" for Caching Method
4. Select "Using a GET request to PURGE/url (Default option)" for Purging Method.
5. Check all of the boxes under Purging Conditions.
6. Save Changes.

## EngineScript Information Reference

### Software EngineScript Utilizes:
#### Domain SSL Certificate Management ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|ACME.sh|Latest|https://get.acme.sh |

#### Web Server ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|NGINX MAINLINE|1.27.3|https://nginx.org/en/download.html |
|NGINX CACHE PURGE|2.5.3|https://github.com/nginx-modules/ngx_cache_purge |
|NGINX HEADERS MORE|0.38|https://github.com/openresty/headers-more-nginx-module |
|NGINX PATCH: Dynamic TLS Records|Latest |https://github.com/kn007/patch|
|GIXY|Latest|https://github.com/yandex/gixy |
|OPENSSL|3.4.0|https://www.openssl.org/source/ |
|PCRE2|10.44|https://github.com/PCRE2Project/pcre2/releases |
|ZLIB-Cloudflare|Latest|https://github.com/cloudflare/zlib |
|ZLIB|1.3.1|https://github.com/madler/zlib |

#### Script Processing ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|PHP|8.3|https://launchpad.net/~ondrej/+archive/ubuntu/php |

#### MySQL Database ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|MARIADB|11.4.4|https://mariadb.org/download/ |
|MYSQLTUNER|Latest|https://github.com/major/MySQLTuner-perl |

#### Database Management ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|ADMINER|| |
|PHPMYADMIN|5.2.2|https://www.phpmyadmin.net/downloads/ |

#### Caching & Performance ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|REDIS|Latest|https://redis.io/ |
|LIBURING|2.8|https://github.com/axboe/liburing|

#### Content Management System (CMS) ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|WORDPRESS | Latest |https://wordpress.org |
|WP-CLI | Latest |https://github.com/wp-cli/wp-cli |
|WP-CLI: Clear OPcache | Latest |https://github.com/wearerequired/wp-cli-clear-opcache|
|WP-CLI: cron-command | Latest |https://github.com/wp-cli/cron-command |
|WP-CLI: doctor-command | Latest |https://github.com/wp-cli/doctor-command|
|WP-CLI: WP Launch Check | Latest |https://github.com/pantheon-systems/wp_launch_check |
|PLUGIN: Nginx Helper *(required)* | Latest |https://wordpress.org/plugins/nginx-helper/ |
|PLUGIN: MariaDB Health Checks *(recommended)* | Latest |https://wordpress.org/plugins/mariadb-health-checks/ |
|PLUGIN: Redis Object Cache *(recommended)*| Latest |https://wordpress.org/plugins/redis-cache/ |
|PLUGIN: The SEO Framework *(recommended)*| Latest |https://wordpress.org/plugins/autodescription/ |
|PLUGIN: App for Cloudflare| Latest |https://wordpress.org/plugins/app-for-cf/ |
|PLUGIN: PHP Compatibility Checker| Latest |https://wordpress.org/plugins/php-compatibility-checker/ |
|PLUGIN: Theme Check| Latest |https://wordpress.org/plugins/theme-check/ |
|PLUGIN: WP Crontrol| Latest |https://wordpress.org/plugins/wp-crontrol/ |
|PLUGIN: WP Mail SMTP| Latest |https://wordpress.org/plugins/wp-mail-smtp/ |

#### Security ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|MALDETECT|Latest|https://www.rfxn.com/projects/linux-malware-detect/ |
|PHP-MALWARE-FINDER|Latest|https://github.com/nbs-system/php-malware-finder |
|UNCOMPLICATED FIREWALL (UFW) | - | Bundled with Ubuntu |
|WORDFENCE CLI||https://github.com/wordfence/wordfence-cli/releases |
|WPSCAN|Latest|https://wpscan.com/|

#### Web Development Tools ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|PNGOUT|20200115|http://www.jonof.id.au/kenutils.html|
|ZIMAGEOPTIMIZER|Latest|https://github.com/zevilz/zImageOptimizer |

#### Backup Software Supported ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|LOCAL BACKUPS| - | Bash Scripts |
|DROPBOX UPLOADER|Latest|https://github.com/andreafabrizi/Dropbox-Uploader |
|AMAZON AWS CLI|Latest|https://aws.amazon.com/cli/ |

#### Network Tools ####
|Software        |Version|Source                    |
|----------------|-------|--------------------------|
|TESTSSL.SH|Latest|https://github.com/testssl/testssl.sh |
||||
||||
||||

### EngineScript Locations
|Location        |Usage                          |
|----------------|-------------------------------|
|**/etc/mysql**                  |MySQL (MariaDB) config |
|**/etc/nginx**                  |Nginx config |
|**/etc/php**                    |PHP config |
|**/etc/redis**                  |Redis config |
|**/home/EngineScript**          |EngineScript user directories |
|**/usr/local/bin/enginescript** |EngineScript source |
|**/var/lib/mysql**              |MySQL database |
|**/var/log**                    |Server logs |
|**/var/www/admin/enginescript** |Tools that may be accessed via your server's IP address |
|**/var/www/sites/*yourdomain.com*/html** |Root directory for your WordPress installation |

### EngineScript Commands
|Command            |Function                       |
|-------------------|-------------------------------|
|**`es.backup`**    |Runs the backup script to backup all domains locally and *optionally* in the cloud |
|**`es.cache`**     |Clear FastCGI Cache, OpCache, and Redis *(server-wide)* |
|**`es.config`**    |Opens the configuration file in Nano |
|**`es.images`**  |Losslessly compress all images in the WordPress /uploads directory *(server-wide)* |
|**`es.info`**    |Displays server information |
|**`es.install`**	  |Runs the main EngineScript installation script |
|**`es.menu`**	    |EngineScript menu |
|**`es.mysql`**	    |Displays your MySQL login credentials in the terminal |
|**`es.permissions`** |Resets the permissions of all files in the WordPress directory *(server-wide)* |
|**`es.restart`**   |Restart Nginx and PHP |
|**`es.server`**    |Displays server information |
|**`es.update`**    |Update EngineScript |
|**`es.variables`** |Opens the variable file in Nano. This file resets when EngineScript is updated |

## Support EngineScript
Need a VPS? EngineScript recommends [Digital Ocean](https://m.do.co/c/e57cc8492285)
