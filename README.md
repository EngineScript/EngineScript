## **EngineScript - Advanced WordPress LEMP Server**

EngineScript automates the process of building a high-performance LEMP server. We've specifically built EngineScript with WordPress users in mind, so the install process will take you from a bare server all the way to a working WordPress installation with Nginx FastCGI cache enabled in about 30 minutes.

EngineScript is meant to be run as root user on a fresh VPS. Initial setup will remove existing Apache, Nginx, PHP, and MySQL installations, so be careful.

As this is a pre-release version, so things might be totally broken day-to-day as things are developed.

#### Features

#### Requirements
- **Ubuntu 20.04**
- **64-Bit OS**
- **Minimum 1GB RAM** *(2GB+ recommended)*
- **Cloudflare** *(free or paid)*
- **30 minutes of your time**

### Install EngineScript
#### Step 1 - Initial Install
Run the following command
```shell
wget https://raw.githubusercontent.com/EngineScript/EngineScript/master/setup.sh && bash setup.sh
```
#### Step 2 - Edit Options File
After the initial setup script has run, you'll need to alter the install options file before continuing.

Edit the following file: **/home/EngineScript/enginescript-install-options.txt**.

Download the file via FTP and edit it using your favorite text editor. You may also edit the file directly from the console using the following command:
```shell
nano /home/EngineScript/enginescript-install-options.txt
```

#### Step 3 - Main Install Process
Once you've filled out the enginescript-install-options.txt file with your personal settings, run the following command to continue with the installation process:
```shell
bash /usr/local/bin/enginescript/enginescript-install.sh
```

----------

#### Domain Creation
After EngineScript is fully installed, type `enginescript` or `es.menu` in console to bring up the EngineScript menu. Choose option **1** to create a new domain.

Domain creation is almost entirely automated, requiring only a few lines entered by the user. During this automated domain creation process, we'll create a unique Nginx vhost file, create new MySQL database, download the latest WordPress release, and assign the applicable data to your wp-config.php file within WordPress.

#### Tuning MySQL

**Run MySQLTuner:**
```shell
perl /usr/local/bin/mysqltuner/mysqltuner.pl
```

### EngineScript Information
#### EngineScript Location Reference
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
|**/var/www/admin**              |Admin Panel root |
|**/var/www/admin/enginescript** |Tools that may be accessed via your server's IP address |
|**/var/www/sites/yourdomain.com/html**|Root directory for your WordPress installation |
|                                |                |

#### EngineScript Commands
|Command            |Function                       |
|-------------------|-------------------------------|
|**`es.compress`**  |Compresses /var/www/sites directories with Brotli and GZIP |
|**`es.menu`**	    |EngineScript menu |
|**`es.mysql`**     |Prints MySQL root login credentials|
|**`es.restart`**   |Restarts Nginx and PHP |
|**`es.update`**    |Updates EngineScript, performs apt full-upgrade |
|**`es.virus`**     |Virus scans /var/www/sites directories with ClamAV |
|**`ng.test`**      |`nginx -t -c /etc/nginx/nginx.conf` |
|**`ng.stop`**      |`ng.test && systemctl stop nginx` |
|**`ng.reload`**    |`ng.test && systemctl reload nginx` |
|                   |                                |

### Support EngineScript
Need a VPS? EngineScript recommends [Digital Ocean](https://m.do.co/c/e57cc8492285)

----------
