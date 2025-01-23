# EngineScript

## A High-Performance WordPress Server Built on Ubuntu and Cloudflare

EngineScript automates the process of building a high-performance LEMP server. We've specifically built EngineScript with WordPress users in mind, so the install process will take you from a bare server all the way to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript is meant to be run as root user on a fresh VPS. Initial setup will remove existing Apache, Nginx, PHP, and MySQL installations, so be careful.

As this is a pre-release version, things may be broken.

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
|                                |                |

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
|                   |                                |

### Software EngineScript Utilizes:

#### Web Server ####
- NGINX MAINLINE - [Link](https://nginx.org/en/download.html)
- NGINX CACHE PURGE - [Link](https://github.com/nginx-modules/ngx_cache_purge)
- NGINX HEADERS MORE - [Link](https://github.com/openresty/headers-more-nginx-module)
- OPENSSL - [Link](https://www.openssl.org/source/)
- PCRE2 - [Link](https://github.com/PCRE2Project/pcre2/releases)
- ZLIB-Cloudflare - [Link](https://github.com/cloudflare/zlib)
- ZLIB - [Link](https://github.com/madler/zlib)

#### Script Processing ####
- PHP - [Link](https://launchpad.net/~ondrej/+archive/ubuntu/php)

#### MySQL Database ####
- MARIADB - [Link](https://mariadb.org/download/)
- PHPMYADMIN - [Link](https://www.phpmyadmin.net/downloads/)

#### Content Management System (CMS) ####
- WordPress - [Link](https://wordpress.org)

#### Security ####
- WORDFENCE CLI - [Link](https://github.com/wordfence/wordfence-cli/releases)

#### Web Development Tools ####
- PNGOUT - [Link](http://www.jonof.id.au/kenutils.html)

#### Backup Software Supported ####


## Support EngineScript
Need a VPS? EngineScript recommends [Digital Ocean](https://m.do.co/c/e57cc8492285)
