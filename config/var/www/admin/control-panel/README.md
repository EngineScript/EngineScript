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

## Installation

EngineScript installs the dashboard to `/var/www/admin/control-panel/` and replaces it on every `es.update`. This `README.md` and `LICENSE` stay in the repository; they are not copied to the server.
