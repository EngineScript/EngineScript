# EngineScript Admin Dashboard

This directory contains the EngineScript admin dashboard, served at `https://admin.yourdomain.com` behind HTTP basic authentication.

## Files

- `index.html` - Dashboard page
- `dashboard.css` - Styles for the light and dark themes
- `dashboard.js` - Dashboard script: pages, data loading, cache buttons, keyboard shortcuts
- `fontawesome-check.js` - Shows a warning when the Font Awesome stylesheet from cdnjs does not load
- `modules/` - API, state, and utility JavaScript modules
- `api.php`, `classes/`, `controllers/` - The dashboard's PHP API
- `favicon.png` - Dashboard favicon

## Features

- **Pages**: Overview, Sites, System, and Tools, with light and dark themes
- **Service status**: Nginx, PHP, MariaDB, and Redis, with their versions, refreshed every five minutes
- **WordPress sites**: Each site's domain, WordPress version, and SSL status
- **Uptime**: The UptimeRobot account's monitors, when an UptimeRobot API key is configured
- **Admin tools**: Links to phpMyAdmin, Adminer (when installed), phpinfo, phpSysInfo, and Tiny File Manager
- **Caches**: The state of Redis, the FastCGI cache, and OPcache, with buttons to clear each

## API

The dashboard reads its data from the API under `/api/`. Every endpoint, parameter, and response is described in [`docs/api.md`](../../../../../docs/api.md).

## Security

### Access

- Nginx asks for HTTP basic authentication on every request to the admin site, before any PHP runs. There is one account: `ADMIN_CONTROL_PANEL_USERNAME` and `ADMIN_CONTROL_PANEL_PASSWORD` from the install options, stored as an APR1 hash in `/etc/nginx/restricted-access/.htpasswd`. Whoever has it can see everything in the dashboard, phpinfo, and phpSysInfo; there are no roles. phpMyAdmin and Tiny File Manager ask for their own login as well.
- The one action that changes something, clearing caches, needs the session's CSRF token. The session cookie is `__Host-esp_session` (`Secure`, `HttpOnly`, `SameSite=Strict`).
- The API counts 100 requests a minute per session. A client that does not send the session cookie back is not limited; only someone with the password can reach the API at all.
- The page's Content Security Policy allows scripts only from the admin site itself, and styles and fonts also from cdnjs.cloudflare.com.

### Data

- **Shown in the dashboard**: service states and versions, the operating system, kernel, host name, and outgoing IP address, each site's domain, WordPress version, and SSL status, cache states, and the UptimeRobot monitors' names, URLs, status, and uptime.
- **Secrets the panel reads but never sends to the browser**: the UptimeRobot API key (`/etc/enginescript/uptimerobot.conf`, `root:www-data` 640) and Tiny File Manager's login hash (`/var/lib/enginescript/admin/tinyfilemanager-auth.json`, `root:www-data` 640). UptimeRobot's monitor records also carry secrets (monitor API keys, HTTP credentials, custom headers); the API keeps only the fields above.
- Nginx passes the basic-authentication header on to PHP (`fastcgi-modified.conf`), so every PHP script on the admin site can read the password, and the phpinfo page shows it. The API uses only the user name, for its log.

### Logs

| Log | What it records |
| --- | --- |
| `/var/log/EngineScript/enginescript-api-security.log` | CSRF failures, refused paths, cache clears, a failed session start, and API errors, each with the time (UTC), the basic-authentication user, and the client address |
| `/var/log/EngineScript/enginescript-api.log` | Failed UptimeRobot requests; never the API key |
| PHP-FPM's error log | Commands the API refused or stopped |
| `/var/log/domains/admin.<domain>-nginx-access.log` and `-nginx-error.log` | Every request to the admin site, the tools included |

Both API logs are `www-data` 644, because PHP writes them.

### Third-party components

| Component | Version | Kept current by |
| --- | --- | --- |
| Font Awesome (from cdnjs) | `FONTAWESOME_VER` in `enginescript-variables.txt` | A daily GitHub Actions check (`software-version-check.yml`) that offers new stable releases once cdnjs serves them; servers get the new version with `es.update` |
| UptimeRobot API v3 | External service | — |
| Tiny File Manager, phpMyAdmin, phpSysInfo, Adminer | `enginescript-variables.txt` | The same daily check; phpMyAdmin is updated from `es.menu` > Update Software > Update Server Tools |

### Time limits

- Each command the API runs (for example `systemctl is-active`) may take 8 seconds, and all commands of one request 20 seconds together.
- UptimeRobot requests may take 10 seconds each and 20 seconds together; the answer is cached for 60 seconds.
- The dashboard gives up on a request after 30 seconds and shows the timeout.

## Installation

EngineScript installs the dashboard to `/var/www/admin/control-panel/` and replaces it on every `es.update`. This `README.md` and `LICENSE` stay in the repository; they are not copied to the server.
