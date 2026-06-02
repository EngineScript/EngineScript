# EngineScript Admin Dashboard

This directory contains the modern admin dashboard for EngineScript server management.

## Files

- `index.html` - Main dashboard HTML shell with modern, responsive design
- `dashboard.css` - Modern CSS styling with dark theme and smooth animations
- `dashboard.js` - Interactive JavaScript for real-time dashboard functionality
- `fontawesome-check.js` - Frontend dependency health check
- `modules/` - API, state, and utility JavaScript modules
- `api.php`, `classes/`, `controllers/` - Standalone PHP API
- `favicon.png` - Dashboard favicon

## Features

- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Real-time Monitoring**: Live server statistics and service status
- **Multi-page Dashboard**: Overview, Sites, System, and Tools
- **Service Management**: Monitor Nginx, PHP, MariaDB, and Redis
- **WordPress Site Management**: View and manage WordPress installations
- **Admin Tools**: Quick access to phpMyAdmin, PHPinfo, and other tools
- **Cache Management**: View and clear Redis, FastCGI, and OPcache caches

## API Integration

The dashboard is designed to work with RESTful API endpoints for real-time data:

- `/api/system/*` - System information and statistics
- `/api/sites/*` - WordPress site management
- `/api/services/*` - Service status monitoring
- `/api/cache/*` - Cache status and clear actions

## Installation

The dashboard is automatically deployed by the EngineScript installation process to `/var/www/admin/control-panel/`.
