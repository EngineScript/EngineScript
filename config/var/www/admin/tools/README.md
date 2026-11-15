# Admin Tools Configuration Templates

This directory contains configuration templates for admin tools that are installed to `/var/www/admin/tools/` on the server.

## Directory Structure

```tree
/var/www/admin/
├── control-panel/    # EngineScript Admin Dashboard (replaced by es.update)
└── tools/            # Admin tools (kept by es.update; see below)
    ├── adminer/
    ├── phpinfo/
    ├── phpmyadmin/
    ├── phpsysinfo/
    └── tinyfilemanager/
```

## Update Behavior

- **Control Panel** (`/var/www/admin/control-panel/`): Replaced by every `es.update`, so the server always runs the dashboard of the installed EngineScript version.
- **Tools** (`/var/www/admin/tools/`): Kept by `es.update`, with two exceptions:
  - every `es.update` copies Tiny File Manager's `config.php` from this directory again, and writes its login from the install options to `/var/lib/enginescript/admin/tinyfilemanager-auth.json`;
  - a PHP update changes the PHP version in `phpsysinfo.ini`.

## Tool-Specific Updates

- **phpMyAdmin**: `es.menu` > Update Software > Update Server Tools (when `INSTALL_PHPMYADMIN=1`)
- **Other tools**: Re-run the respective install script if needed

## Configuration Files

|Tool|Config File|Description|
|-|-|-|
|phpSysInfo|`phpsysinfo.ini`|System monitoring display settings|
|TinyFileManager|`config.php`|File manager authentication and settings|

These template files are copied to the tools during installation. The `SEDPHPVER` placeholder in `phpsysinfo.ini` is replaced with the actual PHP version during installation.
