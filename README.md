# EngineScript

## A High-Performance WordPress Server Built on Ubuntu and Cloudflare

EngineScript automates the process of building a high-performance LEMP server. We've specifically built EngineScript with WordPress users in mind, so the install process will take you from a bare server all the way to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript is meant to be run as root user on a fresh VPS. Initial setup will remove existing Apache, Nginx, PHP, and MySQL installations, so be careful.

As this is a pre-release version.

## Features

## Requirements
- **A Newly Created VPS** *([Digital Ocean](https://m.do.co/c/e57cc8492285) droplet recommended)*
- **Ubuntu 22.04**
- **64-Bit OS**
- **Minimum 1GB RAM** *(2GB+ recommended)*
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

First, retrieve your Cloudflare Global API Key at **https://dash.cloudflare.com/profile/api-tokens**. Then you'll need to edit the configuration file at **/home/EngineScript/enginescript-install-options.txt**. Fill this out completely, making sure to change all options say `PLACEHOLDER`.

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
1. Select your site.
2. Click on the SSL/TLS tab.

#### Click on the Overview section
1. Set the SSL mode to Full (Strict).

#### Click on the Edge Certificates section
1. Set Always Use HTTPS to Off. *(Important: This can cause redirect loops)*
2. Enable HSTS. *(Optional)* We recommend enabling HSTS. However, turning off HSTS will make your site unreachable until the Max-Age time expires. This is a setting you want to set once and leave on forever.
3. Set Minimum TLS Version to TLS 1.3.
4. Enable Opportunistic Encryption.
5. Enable TLS 1.3.
6. Enable Automatic HTTPS Rewrites

#### Click on the Origin Server section
1. Set Authenticated Origin Pulls to On.

#### Click on the Network tab
1. Enable HTTP/2.
2. Enable HTTP/3 (with QUIC). *(Optional)*
3. Enable 0-RTT Connection Resumption. *(Optional)*
4. Enable IPv6 Compatibility. *(Optional)*
5. Enable gRPC. *(Optional)*
6. Enable WebSockets. *(Optional)*
7. Enable Onion Routing. *(Optional)*
8. Set Pseudo IPv4 to Add Header. *(Optional)*
9. Enable IP Geolocation. *(Optional)*

### WordPress Plugins

#### Nginx Helper
1. In WordPress, go to Settings >> Nginx Helper
2. Check Enable Purge.
3. Select "nginx Fastcgi cache" for Caching Method
4. Select "Using a GET request to PURGE/url (Default option)" for Purging Method.
5. Check all of the boxes under Purging Conditions.
6. Save Changes.

#### Super Page Cache for Cloudflare
EngineScript will install the Cloudflare Super Page Cache plugin by default, as it super charges your domain's performance by utlizing the Cloudflare network. We still utilize Nginx FastCGI Cache where applicable as well. This plugin also has some added benefits that apply to EngineScript because it also works with the Nginx Helper plugin, Redis Object Cache, and PHP OpCache to clear out stale caches when the Cloudflare network's cache has been cleared. Use of this plugin is highly recommended for most applications. We've done all of the configuration work within Nginx to get things up and running quickly, but you'll need to follow the steps below before Cloudflare Super Page Cache is up and running.

1. In WordPress, go to Settings >> Super Page Cache for Cloudflare.

##### General tab
1. Retrieve your Cloudflare API key at **https://dash.cloudflare.com/profile/api-tokens**.
2. Authentication mode: **API Key.**
3. Cloudflare email: **Your email.**
4. Cloudflare API Key: **Your API Key.**
5. Log mode: **Whatever you prefer.**
6. Cloudflare Domain Name: ****Your domain.**

##### Cache tab
1. Cloudflare Cache-Control max-age: **31536000**
2. Browser Cache-Control max-age: **60**
3. Automatically purge the Cloudflare's cache when something changes on the website: **Purge cache for related pages only**
4. Don't cache the following dynamic contents: **Check all boxes marked as recommended and then also check "Pages with query args" and "WP JSON endpoints"**
5. Don't cache the following static contents: **Check all boxes marked as recommended**
6. Prevent the following URIs to be cached: **Enter the folowing:**
   ```/*ao_noptirocket*
    /*jetpack=comms*
    /*kinsta-monitor*
    *ao_speedup_cachebuster*
    /*removed_item*
    /my-account*
    /wc-api/*
    /edd-api/*
    /wp-json*
    /checkout/*
    /cart/*
    /certificate/*
    /my-courses/*
    *XMLHttpRequest*
    add-to-cart*
    add_to_cart*
    ```
7. Strip response cookies on pages that should be cached: **No**
8. Automatically purge single post cache when a new comment is inserted into the database or when a comment is approved or deleted: **Yes**
9. Automatically purge the cache when the upgrader process is complete: **Yes**
10. Posts per page: **10** (or whatever you would prefer)
11. Overwrite the cache-control header for Wordpress's pages using web server rules: **Yes**
12. Force cache bypassing for backend with an additional Cloudflare page rule: **Disabled**
13. Purge HTML pages only: **No**
14. Disable cache purging using queue: **No**
15. Worker mode: **Disabled**
16. Enable fallback page cache: **No**
17. Add browser caching rules for static assets: **Yes**
18. Save

##### Advanced tab
1. Enable preloader: **Yes**
2. Automatically preload the pages you have purged from Cloudflare cache with this plugin: **Yes**
3. Preloader operation: **Choose what content you want the preloader to grab. I do all menus and sidebars.**
4. Preload all URLs into the following sitemaps: Enter ```/sitemap.xml```. This assumes you're using The SEO Framework plugin that we automatically installed for you. If you use a different SEO plugin, your sitemap filename may be different.
5. Varnish Support: **No**
6. Automatically purge the OPcache when Cloudflare cache is purged: **Yes**
7. Automatically purge the object cache when Cloudflare cache is purged: **Yes**

##### Third Party tab
Most of these are not used, so just scroll past the ones that say Inactive Plugin.

###### WooCommerce section
1. Don't cache the following WooCommerce page types: **Check all recommended boxes and anything else you want**
2. Automatically purge cache for product page and related categories when stock quantity changes: **Yes**
3. Automatically purge cache for scheduled sales: **Yes**

###### Nginx Helper section
1. Automatically purge the cache when Nginx Helper flushs the cache: **Yes**

##### Other tab
###### Other Settings section
1. Remove Cache Buster Query Parameter: **Yes**

##### Finalize Cloudflare Cache Settings
Follow this tutorial exactly: **https://gist.github.com/isaumya/af10e4855ac83156cc210b7148135fa2**. Things will not work correctly if you skip this part.

## EngineScript Information Reference
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
|**/var/www/sites/*yourdomain.com*/html**|Root directory for your WordPress installation |
|                                |                |

### EngineScript Commands
|Command            |Function                       |
|-------------------|-------------------------------|
|**`es.backup`**    |Runs the backup script to backup all domains locally and *optionally* in the cloud |
|**`es.cache`**     |Clear FastCGI Cache, OpCache, and Redis *(server-wide)* |
|**`es.config`**    |Opens the configuration file in Nano |
|**`es.images`**  |Losslessly compress all images in the WordPress /uploads directory *(server-wide)* |
|**`es.install`**	  |Runs the main EngineScript installation script |
|**`es.menu`**	    |EngineScript menu |
|**`es.mysql`**	    |Displays your MySQL login credentials in the terminal |
|**`es.permissions`** |Resets the permissions of all files in the WordPress directory *(server-wide)* |
|**`es.restart`**   |Restart Nginx and PHP |
|**`es.update`**    |Update EngineScript |
|**`es.variables`** |Opens the variable file in Nano. This file resets when EngineScript is updated |
|                   |                                |

### Software EngineScript Utilizes:
- MARIADB - [https://mariadb.org/download/](https://mariadb.org/download/)
- NGINX CACHE PURGE - [https://github.com/nginx-modules/ngx_cache_purge](https://github.com/nginx-modules/ngx_cache_purge)
- NGINX HEADERS MORE - [https://github.com/openresty/headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module)
- NGINX MAINLINE - [https://nginx.org/en/download.html](https://nginx.org/en/download.html)
- OPENSSL - [https://www.openssl.org/source/](https://www.openssl.org/source/)
- PCRE2 - [https://github.com/PCRE2Project/pcre2/releases](https://github.com/PCRE2Project/pcre2/releases)
- PHP - [https://launchpad.net/~ondrej/+archive/ubuntu/php](https://launchpad.net/~ondrej/+archive/ubuntu/php)
- PHPMYADMIN - [https://www.phpmyadmin.net/downloads/](https://www.phpmyadmin.net/downloads/)
- PNGOUT - [http://www.jonof.id.au/kenutils.html](http://www.jonof.id.au/kenutils.html)
- WORDFENCE CLI - [https://github.com/wordfence/wordfence-cli/releases](https://github.com/wordfence/wordfence-cli/releases)
- ZLIB-Cloudflare - [https://github.com/cloudflare/zlib](https://github.com/cloudflare/zlib)

## Support EngineScript
Need a VPS? EngineScript recommends [Digital Ocean](https://m.do.co/c/e57cc8492285)
