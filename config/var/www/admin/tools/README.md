# Admin Tools Configuration Templates

This directory contains configuration templates for admin tools that are installed to `/var/www/admin/tools/` on the server.

## Directory Structure

```tree
/var/www/admin/
├── control-panel/    # EngineScript Admin Dashboard (updated during es.update)
└── tools/            # Admin tools (NOT affected by es.update)
    ├── adminer/
    ├── opcache-gui/
    ├── phpinfo/
    ├── phpmyadmin/
    ├── phpsysinfo/
    └── tinyfilemanager/
```

## Update Behavior

- **Control Panel** (`/var/www/admin/control-panel/`): Completely replaced during EngineScript updates to ensure users always have the latest dashboard version.
- **Tools** (`/var/www/admin/tools/`): NOT affected by EngineScript updates. Tool configurations persist across updates.

## Tool-Specific Updates

Individual tools can be updated using their respective update commands:

- `es.update.phpmyadmin` - Updates phpMyAdmin
- Other tools: Re-run the respective install script if needed

## Configuration Files

| Tool | Config File | Description |
|------|-------------|-------------|
| phpSysInfo | `phpsysinfo.ini` | System monitoring display settings |
| TinyFileManager | `config.php` | File manager authentication and settings |

These template files are copied to the tools during installation. The `SEDPHPVER` placeholder in `phpsysinfo.ini` is replaced with the actual PHP version during installation.
