# EngineScript Admin Dashboard

This directory contains the modern admin dashboard for EngineScript server management.

## Files

- `index.html` - Main dashboard HTML file with modern, responsive design
- `dashboard.css` - Modern CSS styling with dark theme and smooth animations
- `dashboard.js` - Interactive JavaScript for real-time dashboard functionality
- `favicon.png` - Dashboard favicon (simple placeholder)

## Features

- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Real-time Monitoring**: Live server statistics and service status
- **Interactive Charts**: Performance monitoring with Chart.js
- **Multi-page Dashboard**: Overview, Sites, System, Logs, and Tools
- **Service Management**: Monitor Nginx, PHP, MariaDB, and Redis
- **WordPress Site Management**: View and manage WordPress installations
- **Log Viewer**: Real-time log viewing with filtering
- **Admin Tools**: Quick access to phpMyAdmin, PHPinfo, and other tools

## API Integration

The dashboard is designed to work with RESTful API endpoints for real-time data:

- `/api/system/*` - System information and statistics
- `/api/sites/*` - WordPress site management
- `/api/logs/*` - Log file access
- `/api/services/*` - Service status monitoring

## Future Enhancements

- Real backend API implementation
- User authentication and role-based access
- WebSocket connections for real-time updates
- Advanced monitoring and alerting
- Site deployment and management tools

## Installation

The dashboard is automatically deployed by the EngineScript installation process to `/var/www/admin/control-panel/`.
