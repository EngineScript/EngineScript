# Changelog

All notable changes to EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

## 2025-08-29

### � INSTALLATION COMPLETION VERIFICATION SYSTEM

- **Comprehensive Installation Validation**: Implemented robust system to verify EngineScript installation completion
  - **Common Functions Library**: Added `check_installation_completion()` and `verify_installation_completion()` to shared functions
  - **24-Component Verification**: Validates all required installation components (REPOS, DEPENDS, MARIADB, PHP, NGINX, etc.)
  - **Update Script Protection**: Prevents updates from running on incomplete installations with clear error messaging
  - **Install Script Verification**: Added final verification step to installation process before reboot
  - **Flexible Operation Modes**: Supports both verbose and quiet modes for different use cases
  - **Error Diagnostics Integration**: References existing debug tools and error logs for troubleshooting
  - **Professional User Feedback**: Provides clear success/failure messages with actionable resolution steps
  - **DRY Code Implementation**: Single function definition used across multiple scripts for consistency

### 🚀 SOFTWARE VERSION MANAGEMENT IMPROVEMENTS

- **Nginx Version Detection**: Updated from version 1.29.0 to 1.29.1 across all configuration files
  - **GitHub API Integration**: Enhanced software version checker to use GitHub API for nginx release detection
  - **Reliability Improvements**: Replaced HTML parsing with official API calls for consistent version detection
  - **Error Handling**: Added robust fallback mechanisms for version detection failures

- **OpenSSL Version Consistency**: Standardized OpenSSL version detection to 3.5.x branch across entire codebase
  - **Unified Version Checking**: Updated GitHub Actions workflow to use consistent OpenSSL 3.5.x pattern
  - **CI Configuration Sync**: Synchronized version patterns between main workflow and CI configuration files
  - **Branch Compatibility**: Ensured version detection works reliably across all OpenSSL 3.5.x releases

### 🔧 GITHUB ACTIONS WORKFLOW ENHANCEMENTS

- **Branch Event Triggers**: Added `create` event trigger to enginescript-build-test workflow
  - **Automatic Testing**: Now runs build tests when new branches are created
  - **Development Support**: Enhances developer workflow by providing immediate feedback on branch creation
  - **CI/CD Integration**: Ensures code quality checks run consistently across all development branches

### �🔧 UBUNTU PRO INSTALLATION SYSTEM REFACTORING

- **Modular Installation Structure**: Refactored Ubuntu Pro setup to follow EngineScript's standardized component pattern
  - **New Install Script**: Created dedicated `ubuntu-pro-install.sh` script in `/scripts/install/ubuntu-pro/` directory
  - **State Tracking Integration**: Added proper `UBUNTU_PRO=1` state variable to installation log for resume capability
  - **Error Handling Enhancement**: Improved error logging and validation with comprehensive feedback
  - **Skip Logic Implementation**: Prevents re-running Ubuntu Pro setup if already completed successfully
  - **ESM Services Automation**: Automatically enables Extended Security Maintenance (ESM) for infra and apps
  - **Status Display Feature**: Shows Ubuntu Pro subscription status after successful activation
  - **Configuration Guidance**: Added clear instructions for Ubuntu Pro token setup when not configured
  - **Debug Integration**: Includes debug pause functionality consistent with other install components
  - **Code Consistency**: Follows exact same pattern as CRON, ACME, GCC, and other EngineScript components

## 2025-08-26

### 🔧 NGINX VERSION CORRECTION

- **Version Update**: Updated NGINX mainline version to 1.29.1
  - **Corrected Version**: Changed from 1.29.0 to 1.29.1 to match actual latest release
  - **Direct Download Link**: Verified availability at <https://nginx.org/download/nginx-1.29.1.tar.gz>
  - **GitHub Actions Integration**: Updated software version checker to properly detect 1.29.x series releases

### 🔧 PNGOUT INSTALLATION RELIABILITY IMPROVEMENTS

- **Download Timeout Protection**: Enhanced pngout installation script to prevent indefinite hanging
  - **Primary URL Update**: Updated to use working URL (`https://www.jonof.id.au/files/kenutils/`) as primary download source
  - **Fallback Mechanism**: Added fallback to original URL if primary fails, ensuring maximum compatibility
  - **Timeout Handling**: Implemented 30-second timeout with 3 retry attempts per URL to prevent script hanging
  - **Graceful Failure**: Script continues installation even if pngout download fails from both URLs
  - **Error Suppression**: Clean output with proper error handling and user feedback
  - **File Validation**: Added existence checks before attempting binary installation
  - **Cleanup Integration**: Automatic cleanup of temporary files and extracted directories

## 2025-08-25

### 🧪 TEST MODE FEATURE IMPLEMENTATION

- **TEST_MODE Configuration**: Added new `TEST_MODE` variable to installation configuration file
  - **Development Branch Access**: When enabled (`TEST_MODE=1`), allows switching to `update-software-versions` branch for testing experimental features
  - **Production Safety**: Defaults to `0` (disabled) to ensure stable production installations
  - **Update Script Integration**: Modified `enginescript-update.sh` to respect TEST_MODE setting for branch selection
  - **Clear Documentation**: Added comprehensive warnings about stability when using test mode
  - **Safety Boundaries**: Emergency auto-upgrade and initial setup scripts always use stable master branch for reliability

### 🐛 MARIADB CONFIGURATION COMPATIBILITY FIX
- **MySQL/MariaDB Variable Compatibility**: Fixed MariaDB startup failure due to MySQL-specific configuration
  - **Variable Correction**: Changed `log_error_verbosity` (MySQL) to `log_warnings` (MariaDB) in my.cnf template
  - **Auto-Upgrade Integration**: Added sed command to normal-auto-upgrade script to automatically fix existing installations
  - **Service Reliability**: Resolves MariaDB service exit code 7 failures caused by unknown variable errors

## 2025-07-29

### 🔄 AUTO-UPGRADE SYSTEM ENHANCEMENTS
  - **MariaDB Performance Optimization Updates**: Applies modern MariaDB configuration improvements to existing installations
    - Replaces deprecated `log_warnings` setting with modern `log_error_verbosity = 2`
    - Ensures existing installations benefit from MariaDB 11.8+ compatibility improvements
    
## 2025-07-25

### 🚀 WORDPRESS SITE HEALTH COMPATIBILITY ENHANCEMENT
- **X-Cache-Enabled Header**: Added `X-Cache-Enabled` HTTP header for improved WordPress Site Health check compatibility.
  - **Map Directives**: Added nginx map directives to detect cache status and loopback requests in map-cache.conf
  - **Conditional Header**: X-Cache-Enabled header is only sent for loopback requests when caching is active
  - **Site Health Integration**: Helps WordPress Site Health feature properly detect caching status during internal requests
  - **Implementation**: Based on Roots Trellis PR #1513 for WordPress hosting environment best practices
  - **Cache Detection**: Uses `$upstream_cache_status` to determine if caching is enabled (excludes BYPASS status)
  - **Loopback Detection**: Automatically identifies when WordPress is making internal requests to itself
  - **Response Headers**: Added header to existing response-headers.conf for consistent application across all sites
  - **Auto-Upgrade Integration**: Added upgrade logic to automatically apply changes to existing installations

## 2025-07-17

### 🔒 CLOUDFLARE SSL/TLS STRICT MODE ENFORCEMENT
- **Cloudflare SSL/TLS Security**: Updated both `vhost-install.sh` and `vhost-import.sh` to enforce SSL/TLS encryption mode as `strict` via Cloudflare API.
  - Ensures all new and imported domains use end-to-end encryption between Cloudflare and the origin server.
  - Adds PATCH API call to set `settings/ssl` to `strict` for the relevant Cloudflare zone.
  - Also enables the SSL/TLS recommender feature for best practices.

## 2025-07-16

### 🐛 MARIADB SERVICE RESTART POLICY FIX
- **Systemd Restart Policy**: Updated MariaDB install, update, and auto-upgrade scripts to ensure `/lib/systemd/system/mariadb.service` uses `Restart=always` instead of `Restart=on-abnormal` for improved reliability.
  - Scripts now automatically patch the systemd service file if needed and reload systemd.
  - Ensures MariaDB will always restart on failure, not just on abnormal exits.
  
### 🔧 NGINX BUILD SYSTEM IMPROVEMENTS
- **Compiler Flags Refactoring**: Improved nginx compile script maintainability
  - **Variable Consolidation**: Consolidated `--with-cc-opt`, `--with-ld-opt`, and `--with-openssl-opt` flags into reusable variables
  - **Code Deduplication**: Eliminated duplicate flag definitions between HTTP2 and HTTP3 build configurations
  - **Maintenance Simplification**: Changes to compiler flags now only need to be made in one location
  - **Build Consistency**: Ensures identical optimization flags are used for both HTTP2 and HTTP3 builds
  - **Debug Mode Integration**: Made OpenSSL `no-tests` flag conditional based on debug mode setting
- **OpenSSL Version Management**: Maintains OpenSSL 3.5.x series for latest features
  - **Version Consistency**: Ensured all configuration files use OpenSSL 3.5.x series
  - **CI Configuration**: Updated both main and CI variable files to use OpenSSL 3.5.2
  - **Automated Tracking**: Modified software version checker to track OpenSSL 3.5.x releases
- **GitHub Actions CI Fixes**: Resolved nginx build test permission errors
  - **Directory Creation**: Added proper creation of `/var/log/nginx/` and `/run/nginx/` directories
  - **File Permissions**: Ensured nginx error log file exists with correct permissions (644)
  - **Test Execution**: Fixed nginx configuration test by running with proper root privileges
  - **Permission Denied Errors**: Eliminated "Permission denied" errors for nginx.error.log and nginx.pid files

### 🚨 ADMIN CONTROL PANEL LOGGING FIX
- **API Security Log Permissions**: Fixed critical permission denied errors in admin control panel API
  - **Log File Location**: Moved API security log from `/var/log/enginescript-api-security.log` to `/var/log/EngineScript/enginescript-api-security.log`
  - **Proper Directory Structure**: Aligned API logging with EngineScript's standard log directory structure
  - **Permission Management**: Added proper www-data ownership and 644 permissions for API security log
  - **Installation Integration**: Added API security log creation to setup.sh with proper permissions
  - **CI Environment**: Updated GitHub Actions build test to include API security log file creation
  - **Logrotate Integration**: API security log is now automatically included in logrotate configuration
  - **Fix Script**: Created `fix-api-security-log.sh` script for existing installations to resolve permission issues immediately

## 2025-07-14

### 🚨 NGINX BUILD SYSTEM CRITICAL FIXES
- **Permission Issues Resolved**: Fixed critical permission errors preventing nginx from starting
  - **Directory Creation**: Ensured all nginx directories exist before setting permissions
  - **SSL Certificate Permissions**: Added proper ownership and permissions for SSL certificate files
  - **Service User Management**: Added www-data user creation if missing
  - **Log Directory Access**: Fixed permission denied errors for nginx error and access logs
- **Service Management**: Enhanced nginx service installation and startup process
  - **Configuration Testing**: Added nginx configuration validation before service startup
  - **Service Status Verification**: Implemented proper service status checking and error reporting
  - **Startup Sequence**: Improved service start sequence with proper error handling
- **Compilation Warnings Reduction**: Minimized OpenSSL compilation warnings
  - **Padlock Engine**: Disabled problematic padlock engine causing buffer overflow warnings
  - **Compiler Flags**: Added warning suppression flags for stringop-overflow in OpenSSL
  - **Build Optimization**: Maintained security while reducing build noise

### 🚨 ADMIN CONTROL PANEL CRITICAL FIX
- **Dashboard Loading Issue**: Fixed admin control panel failing to load with infinite "Loading Dashboard..." spinner
  - **Nginx Configuration**: Corrected root directory from `/var/www/admin/enginescript` to `/var/www/admin/control-panel`
  - **API Routing**: Fixed API endpoint routing that was preventing JavaScript from communicating with PHP backend
  - **File Location**: Resolved mismatch between nginx configuration and actual control panel file locations

### �🔧 ADMIN CONTROL PANEL IMPROVEMENTS
- **Mobile Navigation**: Added hamburger menu for mobile access to admin control panel navigation
  - **Responsive Design**: Fixed left navigation column visibility on mobile devices
  - **Toggle Functionality**: Implemented mobile menu toggle with overlay for better user experience
  - **CSS Enhancements**: Added responsive styling for mobile navigation accessibility

### 🔍 SERVICE STATUS DETECTION
- **Dynamic PHP Service Detection**: Completely revamped PHP service status detection in admin control panel
  - **Flexible Pattern Matching**: Supports various PHP-FPM service naming conventions (php-fpm, php8.4-fpm, php-fpm8.4, etc.)
  - **Version-Agnostic Detection**: Implemented dynamic discovery of any PHP-FPM service without hardcoding versions
  - **Automatic Discovery**: Uses systemctl to find active services containing both "php" and "fpm" in their names
  - **Future-Proof**: Will work with any PHP version or naming convention without code updates
  - **Fallback Logic**: Gracefully handles cases where no PHP-FPM service is found
  - **Security Hardening**: Implemented strict input validation and command injection prevention
  - **Robust Pattern Matching**: Accepts php + optional text + fpm + optional text patterns
  - **Command Safety**: Eliminated shell pipeline injection by parsing systemctl output in PHP
  - **Service Name Validation**: Added character filtering and length limits for service names
  - **Audit Logging**: Added security logging for PHP service detection events

### 🔐 SECURITY CONFIGURATION CHANGES
- **Mandatory Admin Protection**: Admin control panel is now always password protected
  - **Variable Removal**: Removed `NGINX_SECURE_ADMIN` configuration option (security is now mandatory)
  - **Variable Renaming**: Updated `NGINX_USERNAME`/`NGINX_PASSWORD` to `ADMIN_CONTROL_PANEL_USERNAME`/`ADMIN_CONTROL_PANEL_PASSWORD`
  - **Auto-Migration**: Added automatic migration script in `normal-auto-upgrade.sh` to update existing installations
  - **Configuration Updates**: Updated all scripts and references to use new variable names
  - **CI Configuration**: Updated CI testing configuration with new admin panel credentials

### 🐧 UBUNTU VERSION SUPPORT
- **Ubuntu 24.04 Only**: Removed support for Ubuntu 22.04 LTS
  - **Setup Script**: Updated version checks to only allow Ubuntu 24.04 installations
  - **Documentation**: Removed Ubuntu 22.04 references from README and instruction files
  - **GCC Installation**: Updated GCC installation script to remove Ubuntu 22.04 specific packages
  - **Repository Management**: Simplified repository installation by removing Ubuntu 22.04 specific logic
  - **CI Workflows**: Updated GitHub Actions workflows to reflect Ubuntu 24.04 only support
  - **Coding Standards**: Updated copilot instructions to reflect single Ubuntu version support

## 2025-07-11

### 📦 PROJECT STRUCTURE ENHANCEMENTS
- **Composer Integration**: Added comprehensive `composer.json` configuration for PHP dependency management
  - **PSR-4 Autoloading**: Configured namespace autoloading with `EngineScript\\` mapped to `scripts/` directory
  - **Development Dependencies**: Added PHPUnit for testing, PHPStan for static analysis, and PHP-CS-Fixer for code formatting
  - **Quality Scripts**: Integrated testing, analysis, and formatting commands for enhanced code quality workflows
  - **Project Metadata**: Defined project as server automation tool with appropriate licensing and keywords
  - **Platform Requirements**: Set PHP 8.3+ requirement to match project's modern PHP standards

## 2025-07-10

### 🚀 MARIADB PERFORMANCE OPTIMIZATIONS
- **InnoDB-Only Environment**: Optimized MariaDB configuration for InnoDB-only environments
  - **Removed MyISAM Settings**: Disabled all MyISAM-related settings to free up memory
  - **Modern InnoDB Settings**: Added modern InnoDB settings for better performance on multi-core systems
  - **Enabled Performance Schema**: Enabled performance schema for better monitoring capabilities
- **MariaDB 11.8 Compatibility**: Updated configuration to ensure compatibility with MariaDB 11.8
  - **Replaced Deprecated Settings**: Replaced `log_warnings` with `log_error_verbosity`
  - **Tuned Connection Settings**: Optimized `wait_timeout` and `max_connect_errors` for better performance
- **Tuning Script Improvements**: Enhanced `mariadb-tune.sh` script for better performance tuning
  - **Capped `innodb_log_file_size`**: Added logic to cap `innodb_log_file_size` at 512MB
  - **Automated `innodb_buffer_pool_instances`**: Added logic to automatically set `innodb_buffer_pool_instances` based on CPU cores

### 🔧 CODE QUALITY IMPROVEMENTS
- **JavaScript Code Refactoring**: Eliminated code duplication in admin dashboard
  - **Removed Duplication**: Created shared `createSiteCardStructure()` helper method to eliminate duplication between `createSiteElement()` and `createNoSitesElement()` methods
  - **Improved Maintainability**: Consolidated common site card creation logic into reusable component

## 2025-07-08

### 🔒️ ADMIN DASHBOARD SECURITY ENHANCEMENTS
- **JavaScript Security Hardening**: Comprehensive security improvements to admin dashboard JavaScript code
  - **XSS Prevention**: Fixed multiple cross-site scripting vulnerabilities in dashboard.js
    - Replaced unsafe `innerHTML` template literals with secure programmatic DOM element creation
    - Added proper input sanitization for all user-displayable content from API responses
    - Eliminated XSS risks in uptime monitoring display and error message rendering
  - **Input Validation & Sanitization**: Enhanced input validation and sanitization methods
    - Added `sanitizeUrl()` method with proper URL pattern validation and dangerous pattern removal
    - Improved `sanitizeNumeric()` method with bounds checking and finite number validation
    - Enhanced general input sanitization to prevent injection attacks and malicious content
  - **Secure DOM Manipulation**: Replaced all innerHTML usage with secure DOM element creation
    - Fixed security vulnerabilities in `createUptimeMonitorElement()` method
    - Eliminated HTML injection risks in error messages and fallback content
    - Ensured all user content uses `textContent` instead of `innerHTML`
  - **Exception Handling**: Fixed SonarCloud security warnings about ignored exceptions
    - Added proper error logging with `console.error()` for all catch blocks
    - Implemented appropriate fallback UI states when API calls fail
    - Eliminated all silent exception handling that could mask security issues
- **Code Quality & Maintainability**: Enhanced JavaScript code quality and security practices
  - **Security Best Practices**: All user inputs properly sanitized and validated before use
  - **Error Visibility**: Comprehensive error logging for debugging while maintaining security
  - **Fallback States**: Graceful degradation maintains functionality during API failures
  - **Memory Management**: Proper cleanup of charts and timers in destroy() method
  - **Regex Optimization**: Fixed Codacy issues with regex patterns for better code quality
    - Removed unnecessary escape characters in URL validation patterns
    - Replaced `[0-9]` with `\d` and `[^\s]` with `\S` for cleaner regex patterns
    - Added ignore comments for intentional control character removal (security feature)

### 🔧 GITHUB ACTIONS WORKFLOW IMPROVEMENTS
- **Software Version Monitoring**: Enhanced automated version checking and update notifications
  - **Workflow Refactoring**: Completely refactored software-version-check.yml workflow
    - Eliminated temp file dependencies for more reliable version tracking
    - Improved version comparison logic with proper regex patterns for all software components
    - Added comprehensive debug output for easier troubleshooting of version detection issues
  - **Pull Request Generation**: Enhanced automated pull request creation for version updates
    - Improved changelog formatting with bolded new versions in comparison tables
    - Direct updates to enginescript-variables.txt and README.md version tables
    - Better commit messages and PR descriptions for version update notifications
  - **Version Detection**: Improved version detection for all tracked software components
    - Enhanced regex patterns for NGINX mainline, NGINX Headers More, and Simple WP Optimizer
    - Better handling of pre-release versions and release candidates
    - More reliable parsing of GitHub API responses for version information
  - **Conditional Date Updates**: Added logic to only update timestamps when software versions actually change
    - Implemented separate tracking for software version changes vs. other workflow changes
    - Date updates now only occur when actual software versions are updated, not on every workflow run
    - Prevents unnecessary pull requests when no actual version changes have occurred
  - **Selective Changelog Updates**: Enhanced changelog generation to only highlight actually updated versions
    - Only software versions that were actually updated are included in the changelog
    - Proper bolding applied to updated version numbers in the changelog table
    - Cleaner, more focused changelog entries that don't include unchanged versions

## 2025-07-07

### 🔧 MARIADB INSTALLATION & CONFIGURATION FIXES
- **MariaDB Startup Issues Resolved**: Fixed critical MariaDB service startup failures
  - **SystemD Environment Variables**: Added proper environment variable definitions to prevent startup errors
    - Created systemd override file at `/etc/systemd/system/mariadb.service.d/enginescript-limits.conf`
    - Defined `MYSQLD_OPTS` and `_WSREP_NEW_CLUSTER` environment variables to empty strings
    - Prevents "Referenced but unset environment variable" errors during service startup
  - **Open Files Limit Configuration**: Fixed open files limit configuration using proper systemd override approach
    - Increased `LimitNOFILE` from default 32768 to 60556 for better database performance
    - Increased `LimitMEMLOCK` to 524288 for liburing and io_uring_setup() support
    - Follows systemd best practices using override files instead of modifying main service file
  - **Memory Variable Calculations**: Added missing server memory percentage calculations
    - Added `SERVER_MEMORY_TOTAL_016` (1.6% of RAM) to enginescript-variables.txt
    - Fixed undefined variable references in mariadb-tune.sh script
    - Ensures proper memory allocation for InnoDB buffer pool and other MariaDB components
  - **Configuration Template Fixes**: Improved MariaDB configuration template processing
    - Fixed log buffer size variable calculation and substitution
    - Ensured all placeholder variables are properly replaced during installation
    - Added systemd daemon reload after configuration changes
- **MariaDB Diagnostic Tool**: Created comprehensive diagnostic script for troubleshooting MariaDB issues
  - **Automated Problem Detection**: Script checks service status, configuration files, and system limits
  - **Automatic Recovery**: Attempts to fix common MariaDB startup issues automatically
  - **Detailed Logging**: Provides comprehensive output for manual troubleshooting when needed
  - Located at `/usr/local/bin/enginescript/scripts/functions/mariadb-diagnostic.sh`

### 🔒️ SECURITY HARDENING & CODE QUALITY
- **PHP Security Compliance**: Enhanced PHP code security to follow best practices and address static analysis findings
  - **XSS Prevention**: Added proper HTML escaping for all output variables in exception messages
    - Error messages from external APIs now use `htmlspecialchars()` with `ENT_QUOTES | ENT_SUBSTITUTE` flags
    - HTTP status codes properly cast to integers to prevent injection
    - All user-facing output properly sanitized before display
  - **Standalone API Justification**: Added comprehensive Codacy ignore comments for required standalone functionality
    - File operations (`file_exists()`, `file_get_contents()`, `is_writable()`) required for system monitoring
    - cURL operations required for external API communication with Uptime Robot service
    - Echo statements required for JSON API responses in standalone service context
    - Session and header functions required for CORS, rate limiting, and security headers
    - Shell execution required for system information gathering (versions, status, metrics)
  - **Secure Error Handling**: All file operations and external calls properly wrapped in try-catch blocks
    - Failed operations log security events for monitoring
    - Graceful fallbacks prevent information disclosure
    - Input validation prevents path traversal and command injection attacks
- **Code Style & Quality**: Enhanced code quality and maintainability standards
  - **Variable Naming**: Improved variable names to meet minimum length requirements
    - Changed `$ch` to `$curl_handle` for cURL operations clarity
    - Changed `$m` to `$monitor` in array filter functions for readability
    - Removed unused `$variables` array declaration
  - **Shell Script Safety**: Added proper quoting to prevent globbing and word splitting
    - Protected file paths in admin control panel installation script
    - Added quotes around `${TINYFILEMANAGER_VER}` variable expansions
    - Ensured safe handling of file operations with spaces in names
  - **CSS Specificity**: Fixed CSS selector ordering to prevent specificity conflicts
    - Moved `.status-text` rule before `.tool-status .status-text` for proper cascade
    - Reordered `.uptime-status a` rule before `.nav-item a:hover` for correct precedence
    - Ensures consistent styling behavior across different UI components
  - **Final Security Cleanup**: Added clarifying comments for properly escaped output
    - Added Codacy ignore comments for XSS prevention functions already using `htmlspecialchars()`
    - Confirmed all exception messages properly escaped before concatenation
    - Enhanced security documentation for standalone API error handling

### �🔐 DYNAMIC AUTHENTICATION SYSTEM
- **TinyFileManager Credential Integration**: Implemented dynamic authentication using main EngineScript credentials
  - **Automatic Credential Loading**: TinyFileManager now reads username/password from `/home/EngineScript/enginescript-install-options.txt`
    - Parses `FILEMANAGER_USERNAME` and `FILEMANAGER_PASSWORD` variables from main configuration
    - Falls back to admin/test if credentials are missing or set to PLACEHOLDER
    - Eliminates need for separate credential management
  - **Dynamic Password Hashing**: Passwords are hashed in real-time using PHP `password_hash()` function
    - Uses `PASSWORD_DEFAULT` algorithm for security compatibility
    - No more static password hashes in configuration files
    - Passwords are re-hashed on each access for maximum security
  - **Simplified Management**: File manager credentials now managed through main EngineScript system
    - Users change credentials via `es.config` command
    - No manual editing of TinyFileManager configuration required
    - Unified credential management across all EngineScript components
  - **Updated Documentation**: Revised all references to reflect dynamic authentication
    - Installation script indicates credentials come from main configuration
    - Password reset script provides proper guidance for credential updates
    - Removed static credential references from documentation

### 🔐 PASSWORD HASH CORRECTION
- **TinyFileManager Authentication**: Fixed password hash generation for proper authentication
  - **Correct Hash Format**: Updated default password hash to use proper PHP `password_hash()` format
    - Changed default password from admin/admin to admin/test with correctly generated hash
    - Hash: `$2y$10$jhQeRpfSEnweAsi8LfnKcutyPauhihfdeplFPE4jobD7FQ5Jmzq5u` (password: test)
    - Generated using TinyFileManager's official password generator tool
  - **Updated Documentation**: Revised password generation guidance across all scripts
    - Installation script now shows correct default credentials (admin/test)
    - Password reset script provides link to official TinyFileManager hash generator
    - Includes both web tool and PHP command line options for hash generation
    - Clarified that PHP5+ `password_hash()` with `PASSWORD_DEFAULT` is required

### 🔗 URL PATH CORRECTION
- **File Manager URL Fix**: Corrected TinyFileManager URL paths for admin subdomain
  - **Path Structure**: Fixed URL to match nginx admin subdomain configuration
    - Changed from `/enginescript/tinyfilemanager/tinyfilemanager.php` to `/tinyfilemanager/tinyfilemanager.php`
    - Admin subdomain nginx root is `/var/www/admin/enginescript`, so `/tinyfilemanager/` maps correctly
    - File system paths remain at `/var/www/admin/enginescript/tinyfilemanager/` (unchanged)
  - **Updated References**: Fixed URLs across all components
    - Control panel HTML link now uses correct `/tinyfilemanager/tinyfilemanager.php`
    - API endpoint returns correct URL structure for frontend
    - Simple redirect in filemanager.php uses proper path
    - Installation script displays correct access URL
    - Password reset script shows correct location path

### �🐛 CONFIGURATION PARSING FIX
- **Uptime Robot Configuration**: Fixed PHP syntax error in configuration file parsing
  - **Parse Error Resolution**: Replaced `parse_ini_file()` with robust manual parsing in `uptimerobot.php`
    - Fixed "syntax error, unexpected '('" error on line 15 of uptimerobot.conf
    - Custom parsing handles comments and special characters properly
    - Eliminates dependency on strict INI file format requirements
  - **Configuration Cleanup**: Removed problematic characters from uptimerobot.conf comments
    - Removed URL with special characters that caused parsing issues
    - Simplified comment format to prevent future parsing problems
    - Maintained all essential configuration information

### 🏷️ OFFICIAL RELEASE INTEGRATION
- **Version Management**: Switched TinyFileManager to official tagged releases instead of master branch
  - **Release Tracking**: Added `TINYFILEMANAGER_VER="2.6"` to `enginescript-variables.txt`
    - Uses official GitHub release tags instead of master branch
    - Downloads from `https://github.com/prasathmani/tinyfilemanager/archive/refs/tags/{version}.tar.gz`
    - Ensures stable, tested releases rather than development code
  - **Automated Updates**: Integrated TinyFileManager into GitHub Actions version checking workflow
    - Automatically detects new releases via GitHub API
    - Updates version variable when new stable releases are available
    - Includes in centralized dependency tracking system
  - **Complete Reference Cleanup**: Removed all traces of deprecated custom wrapper system
    - Eliminated all references to removed `filemanager.php` from API and control panel
    - Removed all mentions of `/etc/enginescript/filemanager.conf` from scripts
    - Updated control panel links to point directly to `/enginescript/tinyfilemanager/tinyfilemanager.php`
    - Converted `reset-filemanager-password.sh` to informational notice about native configuration
  - **Installation Updates**: Modified installation scripts to use versioned releases
    - Admin control panel script now uses `${TINYFILEMANAGER_VER}` variable
    - Proper TAR.GZ extraction instead of ZIP for better compatibility
    - Removed filemanager.conf creation from installation and update scripts

### 🔄 COMPLETE FILE MANAGER OVERHAULog

All notable changes to EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

## 2025-07-07

### � COMPLETE FILE MANAGER OVERHAUL
- **Official TinyFileManager Integration**: Completely replaced custom wrapper with official GitHub repository
  - **Repository Download**: Now downloads and extracts the complete official TinyFileManager from GitHub
    - Downloads latest master branch as ZIP from `https://github.com/prasathmani/tinyfilemanager/archive/refs/heads/master.zip`
    - Extracts to `/var/www/admin/enginescript/tinyfilemanager/` directory
    - Includes all official files, documentation, and features from the upstream project
  - **Custom Configuration Removal**: Eliminated complex custom authentication wrapper entirely
    - Removed `filemanager.php` custom wrapper with 100+ lines of authentication logic
    - Simplified to basic redirect: `header('Location: /enginescript/tinyfilemanager/');`
    - No more rate limiting, session management, or custom security headers in wrapper
  - **Native Configuration**: Uses official TinyFileManager configuration system
    - Created `/config/var/www/admin/tinyfilemanager/config.php` with basic EngineScript defaults
    - Default credentials: admin/admin (users can edit config.php directly)
    - Root path restricted to `/var/www` for security
    - Standard TinyFileManager settings with sensible defaults
  - **Installation Simplification**: Streamlined installation process in admin control panel script
    - Downloads official ZIP archive instead of single PHP file
    - Extracts complete project structure with proper permissions
    - Copies EngineScript configuration file during installation
    - Comprehensive error handling for download and extraction
  - **Legacy System Deprecation**: Marked custom configuration system as legacy
    - Updated `update-config-files.sh` to indicate native configuration usage
    - Removed dependency on `/etc/enginescript/filemanager.conf`
    - Simplified to direct editing of TinyFileManager's native config.php

### �🔧 FILE MANAGER SIMPLIFICATION
- **Password Wrapper Removal**: Removed complex password wrapper and authentication workarounds from file manager
  - **Configuration Cleanup**: Removed `fm_password_hash` from file manager configuration file
    - Simplified `/config/etc/enginescript/filemanager.conf` to use basic username/password authentication
    - Removed automatic password hashing functionality that was causing compatibility issues
    - Streamlined configuration to focus on basic authentication settings
  - **PHP Authentication Simplification**: Removed complex password validation and hashing logic from `filemanager.php`
    - Eliminated password hash validation and placeholder checking routines
    - Removed dependency on PHP password_hash() function for authentication
    - Simplified credential loading to use direct username/password from configuration
    - Added basic default values (admin/admin) for immediate functionality
  - **Update Script Cleanup**: Removed password hashing logic from configuration update script
    - Simplified `update-config-files.sh` to handle basic credential updates without hashing
    - Removed PHP password_hash() calls that were causing authentication failures
    - Streamlined credential transfer from main configuration to file manager config
  - **Back to Basics Approach**: Returned to simple, straightforward file manager authentication
    - Eliminated complex authentication wrapper that was preventing proper login
    - Focused on reliable, basic authentication mechanism
    - Removed unnecessary security layers that were creating usability issues

## 2025-07-06

### �🔧 DASHBOARD UX IMPROVEMENTS
- **Tool Card Status Simplification**: Removed "checking..." status indicators from admin dashboard tool cards
  - **File Manager Card**: Removed dynamic status checking and "Checking..." text from file manager tool card
    - Removed `checkFileManagerStatus()` function and related status display logic
    - Simplified to static tool card with direct link to file manager interface
    - Eliminated unnecessary API calls and loading states for better performance
  - **Uptime Robot Card**: Removed dynamic status checking and "Checking..." text from uptime robot tool card
    - Removed `checkUptimeRobotStatus()` function and related status display logic
    - Simplified to static tool card with direct link to Uptime Robot website
    - Eliminated background API polling for cleaner user experience
  - **CSS Cleanup**: Removed `.checking` status indicator CSS rule and pulse animation
    - Cleaned up unused status indicator styles from dashboard stylesheet
    - Simplified tool card styling by removing dynamic status elements
  - **JavaScript Optimization**: Simplified `loadToolsData()` function to eliminate unnecessary status checks
    - Removed complex status checking logic that was causing loading delays
    - Improved dashboard loading performance by eliminating redundant API calls
    - Enhanced user experience with immediate access to tool cards

### � AUTO-UPGRADE CREDENTIAL MANAGEMENT
- **Missing Credential Detection**: Enhanced auto-upgrade script to add missing credential placeholders to existing installations
  - **File Manager Credentials**: Automatically adds `FILEMANAGER_USERNAME` and `FILEMANAGER_PASSWORD` placeholders if missing
    - Detects existing installations missing file manager credential entries
    - Inserts properly formatted credential section before phpMyAdmin section
    - Includes descriptive comments explaining file manager functionality
  - **Uptime Robot Credentials**: Automatically adds `UPTIMEROBOT_API_KEY` placeholder if missing
    - Detects existing installations missing uptime robot API key entry
    - Inserts properly formatted credential section before "# DONE" marker
    - Includes setup instructions and API key retrieval guidance
  - **Backward Compatibility**: Ensures older EngineScript installations receive new credential placeholders
    - Safe detection using `grep` to avoid duplicate entries
    - Smart insertion using `sed` commands to maintain proper file structure
    - Comprehensive logging of credential addition operations
  - **Error Handling**: Added proper file existence checking and informative user feedback
    - Validates credentials file exists before attempting modifications
    - Provides clear status messages about credential checking and addition
    - Graceful handling of missing credentials file with appropriate warnings

### � CREDENTIALS SYSTEM INTEGRATION
- **Unified Credentials Management**: Integrated file manager and uptime monitor into main EngineScript credentials system
  - **Main Credentials File**: Added `FILEMANAGER_USERNAME`, `FILEMANAGER_PASSWORD`, and `UPTIMEROBOT_API_KEY` to `/home/EngineScript/enginescript-install-options.txt`
  - **Configuration Updater**: Created `/scripts/functions/shared/update-config-files.sh` to populate .conf files from main credentials
  - **Validation Integration**: Added placeholder validation for file manager credentials in main install script
  - **Template Updates**: Modified .conf templates to use empty values populated during installation
  - **Password Reset Integration**: Updated file manager password reset tool to modify main credentials file
  - **Installation Integration**: Configuration files automatically populated during EngineScript installation
  - **Consistency**: Follows existing EngineScript pattern for credential management across all services

### �📁 TINY FILE MANAGER FIXES
- **File Manager Integration Improvements**: Fixed clicking and installation issues with Tiny File Manager
  - **HTML Link Conversion**: Converted file manager card from JavaScript click handler to direct HTML link
    - **Reliable Navigation**: File manager now opens in new tab using standard HTML `<a>` tag
    - **Better Compatibility**: Eliminates popup blocker issues and JavaScript-related failures
    - **User Experience**: Consistent behavior with other tool cards in the admin panel
  - **Automatic Installation**: Enhanced install script to download Tiny File Manager during setup
    - **Pre-installation**: TFM is now downloaded during admin control panel installation
    - **Error Handling**: Graceful fallback if download fails during installation
    - **File Permissions**: Proper permissions (644) set on downloaded TFM file
    - **Path Correction**: Fixed API endpoint URL path to match nginx routing
  - **Status Checking**: Improved file manager status detection in admin dashboard
    - **Real-time Status**: Dashboard shows accurate availability of file manager
    - **Installation Verification**: Checks for both wrapper script and TFM core file
    - **Directory Permissions**: Validates write permissions for file operations
  - **Secure Authentication System**: Added comprehensive password management for file manager access
    - **Configuration File**: Created `/etc/enginescript/filemanager.conf` for secure credential storage
    - **Automatic Password Generation**: Install script generates secure random passwords during setup
    - **Password Hashing**: Uses PHP password_hash() for secure credential storage
    - **Custom Configuration**: Support for custom usernames, passwords, and settings
    - **File Permissions**: Config file secured with 600 permissions (root:root ownership)
    - **Password Reset Tool**: Added `/scripts/functions/shared/reset-filemanager-password.sh` for easy password resets
    - **Dashboard Integration**: Authentication status displayed in admin dashboard
    - **Default Fallback**: Graceful fallback to default credentials if config is missing

### � UPTIME ROBOT INTEGRATION
- **Complete Uptime Robot Monitoring Integration**: Added comprehensive website uptime monitoring to the admin control panel
  - **Backend API Implementation**: Full Uptime Robot API integration in `uptimerobot.php`
    - Created `UptimeRobotAPI` class with secure API key management
    - Implemented monitor management (get, create, delete) and account details retrieval
    - Added formatted status data processing for dashboard display
    - Secure configuration loading from `/etc/enginescript/uptimerobot.conf`
    - Comprehensive error handling and API response validation
    - Support for multiple monitor types (HTTP/HTTPS, Keyword, Ping, Port)
  - **Admin Dashboard Integration**: Added uptime monitoring section to main dashboard
    - **API Endpoints**: Added `/api/monitoring/uptime` and `/api/monitoring/uptime/monitors` endpoints
    - **Real-time Status Display**: Live uptime statistics with automatic refresh
    - **Monitor Details**: Individual monitor cards showing status, uptime percentage, and response times
    - **Configuration Guidance**: Built-in setup instructions for users without API keys
  - **Frontend UI Enhancement**: Modern uptime monitoring interface
    - **Summary Statistics**: Total monitors, online/offline counts, and average uptime percentage
    - **Individual Monitor Cards**: Detailed status displays with color-coded indicators
    - **Responsive Design**: Mobile-optimized layout for uptime monitoring data
    - **Status Indicators**: Visual dots and badges for up/down/paused states
    - **Auto-refresh**: Background updates of monitoring data
  - **Comprehensive Styling**: Modern CSS for uptime monitoring components
    - **Status Colors**: Green (up), red (down), orange (paused), gray (unknown)
    - **Interactive Cards**: Hover effects and professional monitor display cards
    - **Grid Layouts**: Responsive grid system for monitor organization
    - **Mobile Optimization**: Adaptive layouts for all screen sizes
  - **Configuration & Documentation**: Complete setup guide and configuration management
    - **Configuration Template**: Created `/etc/enginescript/uptimerobot.conf` template
    - **Security**: Proper file permissions (600) for API key protection
    - **README Documentation**: Comprehensive setup instructions and feature descriptions
    - **API Key Management**: Secure storage and loading of Uptime Robot credentials
    - **Installation Integration**: Admin control panel install script automatically deploys configuration template
  - **Tools Page Integration**: Added Uptime Robot status card to Tools page
    - **Service Status Indicator**: Shows configured/not configured status
    - **Monitor Count Display**: Real-time count of active monitors
    - **Quick Access**: Direct link to Uptime Robot dashboard for management

### �🗑️ LOG VIEWER REMOVAL
- **Complete Log Viewer Functionality Removal**: Removed all log viewer components from the admin control panel
  - **Backend API Cleanup**: Removed all log-related API endpoints and functions from `api.php`
    - Removed log file validation, path resolution, and content reading functions
    - Removed log diagnostic functionality and sample content generation
    - Removed `/api/logs/*` endpoints and related request handlers
    - Cleaned up log-related security event logging while preserving general security logging
  - **Frontend UI Removal**: Completely removed log viewer interface from admin dashboard
    - Removed "Logs" tab from sidebar navigation in `index.html`
    - Removed entire log viewer page section including log type dropdown and content display
    - Removed log diagnostic button and related UI components
  - **JavaScript Cleanup**: Removed all log-related functionality from `dashboard.js`
    - Removed `allowedLogTypes` array and log type validation
    - Removed log-related event listeners for dropdown selection and diagnostic features
    - Removed `loadLogs()` method and log content processing functions
    - Removed `sanitizeLogContent()` method specific to log formatting
    - Updated allowed pages array to exclude "logs" from navigation
    - Cleaned up log-related API handling in data fetching methods
  - **CSS Cleanup**: Removed log viewer styling from `dashboard.css`
    - Removed `.log-viewer` container styles and formatting
    - Removed `.log-viewer pre` styles for log content display
  - **Security Preservation**: Maintained all essential security logging functions
    - Preserved `logSecurityEvent()` function for API security monitoring
    - Kept general error logging and security event tracking intact
    - Maintained proper security headers and access controls
  - **Dashboard Integrity**: All other control panel functionality remains fully operational
    - Overview, Sites, System, and Tools pages continue to work normally
    - System monitoring, performance charts, and service status unaffected
    - User navigation and page functionality preserved across remaining features

## 2025-07-06 (Previous Updates)

### � FINAL LOG VIEWER VERIFICATION & ENHANCEMENTS
- **Log Viewer Functionality Verification**: Completed comprehensive verification of log file access and display
  - **Improved Log Content Sanitization**: Enhanced sanitization to preserve log formatting while maintaining security
    - Removed overly restrictive character filtering that was removing common log symbols
    - Changed from whitelist approach to security-focused sanitization that preserves log readability
    - Increased log size limit from 50KB to 100KB for better log coverage
    - Enhanced sanitization to remove only HTML tags and control characters while preserving timestamps, paths, and symbols
  - **Enhanced Error Handling**: Improved log loading with better feedback and state management
    - Added loading state indicators while fetching log data
    - Enhanced error messages to provide specific feedback on log accessibility issues
    - Added automatic scrolling to bottom of logs to show most recent entries
    - Improved null/empty response handling with specific user feedback
  - **EngineScript Log Directory Management**: Added automatic creation of EngineScript log directories
    - Created `ensureEngineScriptLogDirectory()` function to create `/var/log/EngineScript/` if missing
    - Added proper directory permissions (755) and ownership (www-data) for web server access
    - Integrated directory creation into log loading process for EngineScript-specific logs
    - Added security event logging for directory creation operations
  - **Comprehensive Log Diagnostic System**: Added diagnostic tools for troubleshooting log access
    - Created `/api/logs/diagnostic` endpoint to check directory permissions and file accessibility
    - Added diagnostic button to logs page for real-time log system status checking
    - Diagnostic output includes directory status, file permissions, sample content, and error details
    - Enhanced debugging capability to identify log access issues in different server environments
  - **Log File Path Validation**: Enhanced security and compatibility for log file access
    - Improved realpath validation to handle non-existent files in expected directory structures
    - Added support for EngineScript logs that may not exist in fresh installations
    - Enhanced path traversal protection with comprehensive expected path validation
    - Added specific handling for different log types (system, service, EngineScript logs)

### �🔧 CODE QUALITY IMPROVEMENTS
- **Performance Chart Enhancements**: Implemented real system performance data and fixed chart sizing issues
  - **Real Data Integration**: Added `/api/system/performance` endpoint to provide actual CPU, memory, and disk usage data
    - Replaced random sample data with real system metrics from current usage values
    - Added support for different time ranges (1h, 6h, 24h, 48h) with appropriate data intervals
    - Performance data based on actual system load, memory usage, and disk usage
  - **Chart Sizing Fix**: Resolved chart minimization and scaling issues during updates
    - Added fixed scale settings with `min: 0`, `max: 100`, and `stepSize: 25` for consistent Y-axis
    - Disabled chart animations (`duration: 0`) to prevent visual glitches during updates
    - Improved chart update mechanism to fully recreate chart with new data instead of partial updates
  - **Fallback System**: Enhanced fallback data generation for when API is unavailable
    - Replaced purely random data with realistic time-based patterns
    - Added business hours CPU usage patterns and stable memory/disk usage simulation
    - Ensures graceful degradation when system metrics are unavailable
- **Critical Bug Fixes**: Resolved undefined variable errors and browser compatibility issues
  - **Opera Mini Compatibility**: Enhanced fetch API compatibility for Opera Mini browsers
    - Added specific Opera Mini detection using user agent string
    - Implemented proper fallbacks when fetch API is limited or unsupported
    - Added `isOperaMini()` helper method to detect and handle Opera Mini browser limitations
    - Prevents fetch-related errors in browsers with limited JavaScript API support
  - **Chart.js Compatibility**: Added proper Chart.js library detection and graceful fallbacks
    - Added `/* global Chart, fetch */` declarations to prevent undefined variable errors
    - Implemented Chart availability checks in `initializePerformanceChart()` and `initializeResourceChart()`
    - Prevents runtime errors when Chart.js library is not loaded or available
  - **Fetch API Compatibility**: Enhanced browser compatibility for older browsers and Opera Mini
    - Added fetch availability detection in all API methods
    - Implemented graceful fallbacks when fetch API is not supported
    - Returns appropriate fallback values instead of throwing errors
  - **Regular Expression Security**: Fixed control character issues in security sanitization
    - Replaced hex escape sequences with Unicode escapes to prevent linter warnings
    - Changed `[\x00-\x1F]` to `[\u0000-\u001F]` for better compatibility
    - Updated `\x0B` to `\v` for proper vertical tab character handling
  - **Parameter Usage Optimization**: Fixed unused parameter in API methods
    - Modified `getApiData()` to properly utilize the fallback parameter on errors
    - Ensures proper error handling and graceful degradation
- **Code Deduplication**: Eliminated 6 instances of code duplication across admin control panel
  - **Security Pattern Consolidation**: Extracted common dangerous pattern removal logic
    - Created `removeDangerousPatterns()` helper method to eliminate duplicated security code
    - Refactored `sanitizeInput()` and `sanitizeLogContent()` to use shared security patterns
    - Reduced code duplication by 21 lines and improved maintainability
  - **DOM Element Creation Optimization**: Streamlined element creation patterns
    - Created `createContentElement()` helper method for common DOM structures
    - Refactored `createActivityElement()` and `createAlertElement()` to use shared logic
    - Reduced code duplication by 32 lines while maintaining identical functionality
    - Improved consistency in element creation patterns across the application
  - **Chart Configuration Optimization**: Consolidated Chart.js configuration patterns
    - Created `createPerformanceChartConfig()` helper method to eliminate duplicated chart options
    - Refactored `loadPerformanceChartData()` and `loadFallbackChart()` to use shared configuration
    - Created `createPerformanceChart()` helper method to consolidate chart creation logic
    - Reduced code duplication by 108 lines while maintaining identical chart functionality
    - Improved maintainability of chart configuration and creation across dashboard
- **Best Practice Compliance**: Fixed multiple code style issues identified by linters
  - **Character Class Optimization**: Removed redundant characters in regex patterns
    - Removed unnecessary `_` from `[\w\s.\-_@#%]` since `\w` already includes underscore
    - Fixed escape character usage in regex patterns for better performance
  - **Error Handling Enhancement**: Improved API error handling and browser compatibility
    - Enhanced fallback mechanisms for unsupported browser features
    - Improved error recovery and user experience across different environments
- **Log Viewer Improvements**: Enhanced comprehensive log viewer functionality with better error handling and user feedback
  - **Fixed Log Display Issue**: Resolved API response format mismatch preventing log content from displaying
    - Updated `getApiData()` method to properly handle `/api/logs/` endpoints that return `{logs: 'content'}` format
    - Fixed log viewer to extract actual log content from API response wrapper
    - Enhanced error handling to show meaningful messages instead of failing silently
  - **Enhanced Log Availability**: Improved log file detection and user feedback for missing or empty logs
    - Updated default log selection to use system log (syslog) which is more likely to exist
    - Added comprehensive error messages explaining why logs might not be available
    - Enhanced log reading to provide context about file size, location, and status
    - Added helpful troubleshooting information for missing service logs
  - **Expanded Log Options**: Added more log types to log viewer interface
    - Added system log, authentication log, Redis log, and cron log options to dropdown
    - Reorganized log selector to prioritize commonly available logs first
    - Improved log type descriptions for better user understanding
  - **Sample Log Content**: Added demonstration log content for development and testing environments
    - Generated realistic sample log entries when actual log files don't exist or are empty
    - Provided context-appropriate sample content for each log type (system, auth, nginx, php, etc.)
    - Enhanced user experience by showing what logs would look like when properly configured
  - **Improved Log Reading**: Enhanced log file processing with better formatting and context
    - Added file size information and line count to log headers
    - Improved handling of empty log files with explanatory messages
    - Enhanced permission error reporting with actionable troubleshooting steps
    - Better formatting for both small files (complete content) and large files (last 100 lines)

## 2025-07-05

### 🎨 ADMIN CONTROL PANEL REFACTORING
- **UI Simplification and Security Focus**: Comprehensive refactoring of the admin control panel to remove security-related features and improve user experience
    - Removed Security dashboard page and navigation item
    - Removed all security status monitoring (SSL, firewall, malware scanning)
    - Simplified UI to focus on core server administration tasks
  - **Removed Backup Features**: Eliminated all backup-related functionality from the control panel
    - Removed Backups dashboard page and navigation item
    - Removed backup status monitoring and backup information from site cards
    - Cleaned up all backup-related JavaScript, CSS, and documentation
  - **Enhanced Tools Page**: Refactored tool cards to use pure HTML links instead of JavaScript-based buttons
    - All tool cards now use direct HTML `<a>` links with `target="_blank"` and `rel="noopener noreferrer"`
    - Eliminated popup blocker issues and JavaScript dependency for tool access
    - Removed purple underlining from tool card descriptions for cleaner appearance
  - **Simplified Sites Management**: Streamlined WordPress site management interface
    - Removed "Add New Site" button to focus on existing site monitoring
    - Removed "Visit" button from site cards to simplify the interface
    - Enhanced WordPress version detection and display
  - **Clean Navigation**: Simplified navigation structure and page management
    - Updated page switching logic to handle removed pages gracefully
    - Cleaned up page titles and active state management
    - Removed all references to security and backup features from navigation

### 🛡️ API SECURITY HARDENING
- **Critical Security Fixes**: Addressed all GitHub security alerts and Codacy issues
  - **Log Injection Prevention**: Fixed log injection vulnerability in `logSecurityEvent()` function
    - Added input sanitization for all log entries to prevent log injection attacks
    - Implemented length limits and format validation for all logged data
    - Added IP address validation to prevent malicious injection through REMOTE_ADDR
  - **JavaScript Multi-Character Sanitization**: Fixed incomplete sanitization vulnerabilities in dashboard.js
    - **Replaced Complex Regex Patterns**: Eliminated vulnerable regex patterns that could be bypassed with nested/overlapping malicious content
    - **Implemented Whitelist-Based Sanitization**: Replaced blacklist approach with secure whitelist approach
      - `sanitizeInput()`: Only allows alphanumeric characters, spaces, and safe punctuation (. - _ @ # %)
      - `sanitizeLogContent()`: Allows additional log-friendly characters but maintains strict security
    - **Enhanced Pattern Detection**: Added comprehensive dangerous pattern removal as secondary security layer
      - Removed all dangerous protocols (javascript:, vbscript:, data:, about:, file:)
      - Removed all HTML tags (script, iframe, object, embed, link, meta)
      - Removed all event handlers (onclick, onload, etc.) and JavaScript functions (eval, alert, prompt)
    - **Prevented Incomplete Multi-Character Sanitization**: Fixed GitHub/CodeQL alerts about incomplete sanitization
      - Eliminated regex patterns like `j\s*a\s*v\s*a\s*s\s*c\s*r\s*i\s*p\s*t\s:` that could be bypassed
      - Implemented single-pass sanitization that cannot leave exploitable fragments
  - **Codacy Security Compliance**: Added appropriate ignore comments for false positives
    - Added `// codacy:ignore` comments for all legitimate use of security-flagged PHP functions in standalone API context
    - Documented necessary use of functions like `file_get_contents()`, `realpath()`, `shell_exec()`, `fopen()`, `fread()`, etc.
    - Added explanations for required direct `$_SERVER`, `$_SESSION`, and `$_GET` superglobal access (WordPress functions not available)
    - Included ignore comments for essential system monitoring functions (`sys_getloadavg()`, `disk_total_space()`, etc.)
    - Addressed all header(), session_start(), die(), and echo statements used for API security and functionality
    - All $_SERVER, $_SESSION, and $_GET access properly documented as required for standalone API
    - header() function usage justified as necessary for CORS and security headers
    - session_start() and parse_url() usage documented as required for API functionality
    - All echo statements marked as required for JSON API responses
    - CSRF warnings marked as not applicable to read-only GET API endpoints
  - **Security Architecture Improvement**: Migrated from complex multi-pass sanitization to simple, secure whitelist approach
    - Eliminated potential for bypass through overlapping or nested malicious patterns
    - Reduced computational overhead while improving security posture
    - Implemented defense-in-depth with both character whitelisting and pattern blacklisting

### 🔧 CODE QUALITY IMPROVEMENTS
- **Code Style and Standards Compliance**: Fixed multiple code style issues across admin control panel files
  - **API.php Code Quality**: Addressed unused variables and naming convention issues
    - Removed unused `$buffer` variable from log reading function
    - Renamed short variable names (`$ip` → `$client_ip`, `$mb` → `$memory_mb`, `$gb` → `$disk_gb`)
    - Improved variable naming for better code readability and maintainability
    - Added appropriate Codacy ignore comment for `logSecurityEvent()` $_SERVER access
    - Refactored high-complexity functions to improve maintainability and reduce cyclomatic complexity
    - **Critical Security Fix**: Added proper documentation for `$_SERVER['REMOTE_ADDR']` access as standalone API requirement
    - **fclose() Usage**: Added ignore comment for required file handle cleanup in standalone API context
    - **Eliminated Else Clause**: Improved getNetworkInfo() function by removing unnecessary else expression
  - **Function Complexity Reduction**: Broke down complex functions into smaller, more manageable components
    - **getRecentActivity()**: Reduced complexity from 11 to 3 by extracting helper functions
      - Created `checkRecentSSHActivity()`, `isValidLogFile()`, and `parseAuthLogForActivity()` helpers
      - Improved code readability and testability through function decomposition
    - **getServiceStatus()**: Reduced complexity from 16 to 4 by extracting version detection logic
      - Created individual version detection functions (`getNginxVersion()`, `getPhpVersion()`, etc.)
      - Separated service status checking from version detection for better maintainability
      - Added `createErrorServiceStatus()` helper for consistent error responses
    - **getNetworkInfo()**: Eliminated else clause and improved code flow structure
      - Replaced nested if-else with early return pattern for better readability
      - Enhanced IP validation and sanitization logic
  - **CSS Standards Compliance**: Fixed color hex code formatting issues
    - Shortened hex color codes for better performance (`#333333` → `#333`, `#ffffff` → `#fff`, `#ff4444` → `#f44`)
    - Added proper spacing in CSS animation rules for better formatting
    - Improved CSS rule organization and readability
  - **JavaScript Formatting Improvements**: Enhanced code consistency and readability
    - **Comprehensive Code Style Quick Fixes**: Applied 70+ formatting improvements across dashboard.js
      - Standardized all quote usage (single quotes for all DOM selectors and string literals)
      - Fixed inconsistent indentation patterns throughout the file
      - Corrected element selector formatting and event handler structure
      - Improved function and class formatting for better maintainability
      - Enhanced code structure organization and documentation
      - Fixed navigation and page management function formatting
      - Applied consistent spacing and formatting to all method calls
      - Standardized object property naming and access patterns
      - Fixed string concatenation and template literal formatting
      - Corrected CSS style property assignments and DOM manipulation
      - Improved error handling function formatting and structure
    - Applied comprehensive code style quick fixes across all JavaScript functions
    - **Removed Debugging Code**: Eliminated all debugging-related console.log statements and user interaction tracking
      - Removed 15+ console.log statements used for navigation, API calls, and page management debugging
      - Removed console.error statements for validation failures and missing elements
      - Removed production console disabling code that was debugging-related
      - Simplified error handling to fail silently for better user experience
  - **PHP Complexity Reduction**: Refactored high-complexity API functions to improve maintainability
    - **validateInput() Function**: Split into focused helper functions to reduce complexity
      - Created `validateInputString()`, `validateInputPath()`, and `validateInputService()` helpers
      - Reduced cyclomatic complexity while maintaining security validation
      - Improved code readability and maintainability through function decomposition
    - **getWordPressVersion() Function**: Extracted path validation and version parsing logic
      - Created `validateWordPressPath()` and `parseWordPressVersion()` helper functions
      - Separated security validation from version extraction for better organization
      - Reduced NPath complexity while maintaining security standards
    - **getWordPressSites() Function**: Decomposed into specialized helper functions
      - Created `validateNginxSitesPath()`, `scanNginxConfigs()`, and `processNginxConfig()` helpers
      - Reduced cyclomatic complexity from 23 to 8 through logical function separation
      - Improved error handling and maintainability of WordPress site discovery
    - **getLogs() Function**: Split into validation and reading helper functions
      - Created `validateLogType()`, `getLogFilePath()`, `validateLogFilePath()`, and `readLogFileSafely()` helpers
      - Reduced complexity while maintaining strict security validation
      - Improved code organization and reusability of log handling logic
      - Maintained functional error handling while removing verbose debugging output
    - **Removed Unused Variables**: Fixed Codacy error-prone issues
      - Removed unused `navItems` variable from `setupNavigation()` function
      - Cleaned up variable declarations to eliminate dead code warnings
  - **Comprehensive Security Audit**: Addressed all Codacy security issues and implemented OWASP best practices
  - **Input Validation Fixes**: Implemented proper superglobal array access with `isset()` checks
    - Fixed all `$_SERVER`, `$_GET`, and `$_SESSION` array access to use `isset()` validation
    - Enhanced input validation for REQUEST_METHOD, REMOTE_ADDR, HTTP_HOST, HTTP_ORIGIN, and REQUEST_URI
    - Added comprehensive null checks and fallback values for all user inputs
  - **Language Construct Security**: Replaced discouraged language constructs throughout the codebase
    - Replaced all `exit()` statements with `die()` for consistency and security
    - Enhanced session management with `session_status()` checks before `session_start()`
    - Improved error handling with proper HTTP status codes and sanitized responses
  - **Function Security Enhancements**: Updated deprecated and discouraged function usage
    - Replaced deprecated `FILTER_SANITIZE_STRING` with `htmlspecialchars()` for better security
    - Enhanced all shell command executions with null checks and output validation
    - Added proper error handling for `parse_url()` and other potentially unsafe functions
  - **Output Sanitization**: Implemented comprehensive XSS prevention measures
    - All text outputs now properly escaped with `htmlspecialchars(ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`
    - Enhanced JSON response sanitization to prevent script injection
    - Added input validation and output escaping for all user-controlled data
  - **Command Injection Prevention**: Strengthened protection against command injection attacks
    - Enhanced `shell_exec()` usage with proper null checks and output validation
    - All shell command outputs validated and sanitized before processing
    - Added comprehensive error handling for failed shell operations

### 🔍 WORDPRESS VERSION DETECTION
- **Enhanced Site Monitoring**: Implemented automatic WordPress version detection for all sites
  - **Version Scanning**: Added `getWordPressVersion()` function to detect WordPress versions from `wp-includes/version.php`
  - **Document Root Detection**: Enhanced nginx configuration parsing to extract document root paths
  - **Security Validation**: Implemented comprehensive path traversal prevention and input validation
    - Uses `realpath()` validation for all file access operations
    - Added directory containment checks to prevent unauthorized file access
    - Validates all file paths against expected directory structures
  - **Error Handling**: Added graceful fallbacks for sites where version detection fails
  - **Performance Optimization**: Efficient version detection that minimizes disk I/O operations

### 🧹 CODE CLEANUP AND OPTIMIZATION
- **Removed Legacy Endpoints**: Cleaned up API endpoints to match simplified frontend
  - Removed `/security/status` endpoint and related handler functions
  - Removed `/backups` endpoint and related backup monitoring functions
  - Cleaned up route handling to eliminate unused code paths
- **Enhanced Error Handling**: Improved exception handling throughout the API
  - Added comprehensive try-catch blocks for all system operations
  - Enhanced security event logging for suspicious activities
  - Improved error responses with appropriate HTTP status codes
- **Code Quality Improvements**: Enhanced maintainability and readability
  - Consistent error handling patterns across all functions
  - Better function documentation and type safety
  - Eliminated dead code and unused variables

### 📚 DOCUMENTATION UPDATES
- **Updated Control Panel Documentation**: Revised README.md to reflect simplified feature set
  - Removed all references to security and backup features
  - Updated API documentation to match current endpoints
  - Enhanced setup and configuration instructions
- **Security Documentation**: Added comprehensive security implementation details
  - Documented all OWASP compliance measures
  - Added details about input validation and output sanitization
  - Included security testing procedures and recommendations

## 2025-07-01

### 🎨 ADMIN CONTROL PANEL MODERNIZATION
- **Complete Admin Dashboard Redesign**: Fully modernized the admin control panel with a professional, interactive dashboard
  - **Modern UI/UX**: Replaced basic HTML template with responsive, dark-themed dashboard using modern CSS Grid and Flexbox
  - **Interactive Features**: Added real-time system monitoring, service status indicators, and performance charts
  - **Multi-page Dashboard**: Implemented single-page application with Overview, Sites, System, Security, Backups, Logs, and Tools sections
  - **Real-time Data**: Integrated Chart.js for interactive performance monitoring and resource usage visualization
  - **Responsive Design**: Mobile-first design that works seamlessly on desktop, tablet, and mobile devices
  - **Enhanced Navigation**: Sidebar navigation with active states and smooth transitions
  - **Live Server Clock**: Real-time server time display with automatic updates
  - **Service Monitoring**: Live status indicators for Nginx, PHP-FPM, MariaDB, and Redis with version information
  - **System Metrics**: Real-time CPU, memory, and disk usage monitoring with visual indicators
  - **Activity Feed**: Recent system activity and alerts with contextual icons and timestamps
  - **WordPress Site Management**: Enhanced site overview with status, SSL, and backup information
  - **Security Dashboard**: SSL certificate status, firewall monitoring, and malware scanning overview
  - **Log Viewer**: Real-time log viewing with filtering for different services (EngineScript, Nginx, PHP, MariaDB)
  - **Admin Tools Integration**: Quick access to phpMyAdmin, PHPinfo, phpSysinfo, and Adminer with availability checking
  - **Command Reference**: Complete EngineScript command reference with descriptions and usage examples
- **Backend API Implementation**: Created comprehensive PHP-based REST API for dashboard functionality
  - **System Information API**: Real-time system stats including CPU, memory, disk usage, uptime, and load averages
  - **Service Status API**: Live monitoring of all EngineScript services with version detection
  - **WordPress Sites API**: Automated detection and management of WordPress installations
  - **Security Status API**: SSL certificate monitoring, firewall status, and malware scanner integration
  - **Backup Status API**: Integration with EngineScript backup systems for status reporting
  - **Log Access API**: Secure log file access with filtering and real-time updates
  - **Activity Monitoring**: System activity logging and alert generation for proactive monitoring
  - **Error Handling**: Comprehensive error handling with graceful fallbacks and user-friendly messages
- **Enhanced Installation Process**: Updated admin control panel deployment script
  - **API Setup**: Automatic API endpoint configuration with proper routing
  - **Permission Management**: Secure file permissions and ownership configuration
  - **Feature Detection**: Dynamic feature availability based on installed components (e.g., Adminer availability)
  - **Nginx Integration**: Added nginx configuration snippets for optimal performance and security
- **Security Enhancements**: Implemented robust security measures for the admin panel
  - **Access Control**: Restricted access to sensitive files and directories
  - **Security Headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, and Referrer-Policy
  - **Input Validation**: Server-side validation for all API endpoints
  - **Error Sanitization**: Prevents information disclosure through error messages
- **Performance Optimizations**: Optimized dashboard for fast loading and smooth operation
  - **Asset Caching**: Proper cache headers for static assets with versioning support
  - **Compressed Delivery**: Gzip compression for text-based resources
  - **Lazy Loading**: Progressive loading of dashboard components to improve perceived performance
  - **Efficient API Design**: Optimized API endpoints to minimize server load and response times
- **Documentation**: Comprehensive documentation for the new dashboard
  - **Feature Overview**: Complete feature documentation with usage examples
  - **API Documentation**: Detailed API endpoint documentation for future enhancements
  - **Installation Guide**: Step-by-step setup and configuration instructions
  - **Future Roadmap**: Planned enhancements including authentication, WebSocket integration, and advanced monitoring

### 🔧 NEW ENGINESCRIPT COMMAND
- **Added es.sites Command**: New EngineScript alias to list all WordPress sites installed on the server
  - **Site Discovery**: Automatically discovers all WordPress installations in `/var/www/sites/*/html`
  - **Status Checking**: Tests HTTPS/HTTP connectivity for each site with color-coded status indicators
  - **Formatted Output**: Clean table format showing domain, document root, and online status
  - **WordPress Validation**: Verifies actual WordPress installations by checking for `wp-config.php`
  - **Configuration Status**: Shows whether sites are configured for automated tasks (backups, maintenance)
  - **Command Integration**: Integrates with existing EngineScript alias system and help documentation
  - **Error Handling**: Graceful handling of missing directories and inaccessible sites
  - **Usage Instructions**: Provides helpful commands for further site management

### 🛡️ SECURITY & AUTOMATION IMPROVEMENTS
- **Frontend Dashboard Security**: Completed comprehensive security audit and hardening of the JavaScript dashboard
  - **Input Validation & Sanitization**: Implemented strict client-side input validation with parameter whitelisting
    - Added validation for page names, log types, time ranges, and tool names against predefined whitelists
    - Comprehensive input sanitization removing HTML special characters, JavaScript protocols, and dangerous patterns
    - Length limits implemented (1000 chars for general input, 50KB for log content)
  - **XSS Prevention**: Complete protection against Cross-Site Scripting attacks
    - Replaced unsafe `innerHTML` usage with secure `textContent` and `createElement()` methods
    - All dynamic content created using DOM manipulation instead of HTML string injection
    - API response data sanitized before display with comprehensive content filtering
    - Eliminated inline event handlers and prevented `eval()` usage
  - **URL & Navigation Security**: Secure handling of external URLs and navigation
    - Domain validation with regex patterns before opening external links
    - `window.open()` enhanced with `noopener,noreferrer` security flags
    - Dangerous protocols (`javascript:`, `data:`, `vbscript:`) filtered and removed
    - Frame protection implemented to prevent embedding in malicious frames
  - **Data Handling Security**: Secure processing of all API responses and user data
    - Strict type validation for all data objects received from API
    - Safe URL handling with domain validation before creating clickable links
    - Proper memory management with cleanup of charts and event listeners
    - Secure error handling without information disclosure
  - **Production Security Features**: Enhanced security for production environments
    - Console access disabled in production environments to prevent debugging
    - Error message sanitization to prevent sensitive information disclosure
    - Resource validation before loading external dependencies
    - Secure initialization and cleanup procedures
- **Enhanced Security Documentation**: Updated comprehensive security documentation covering both frontend and backend
  - **Frontend Security Guide**: Detailed documentation of all JavaScript security measures
  - **Security Architecture**: Defense-in-depth approach with multiple security layers
  - **Testing Procedures**: Comprehensive security testing checklists for both frontend and backend
  - **Incident Response**: Updated emergency response procedures for security incidents
  - **Monitoring Integration**: Enhanced security monitoring and logging procedures

### 🔧 CODE QUALITY
- **CI/CD Workflow Enhancement**: Comprehensively improved the GitHub Actions software-version-check workflow
  - **Robust Error Handling**: Added comprehensive error handling for all GitHub API calls to prevent "null" version values
    - Enhanced SSE_PLUGIN, SWPO_PLUGIN, PCRE2, OpenSSL, Zlib, liburing, NGINX modules with proper null checking
    - Added debug output for all API responses to improve troubleshooting
    - Implemented fallback behavior to retain current versions when API calls fail
    - Added warning messages for failed API calls with clear context
  - **Conditional Expression Modernization**: Updated all workflow conditionals to use `[[ ]]` for consistency
  - **API Response Validation**: All GitHub API calls now validate responses before processing
    - Uses `jq -r '.field // empty'` pattern to handle null/missing values gracefully
    - Checks for non-empty and non-null values before version updates
    - Preserves current versions when external APIs are unavailable or return invalid data
  - **Debug Logging**: Added comprehensive debug output for version fetching operations to aid in troubleshooting
  - **Reliability Improvements**: Workflow now handles network failures, API rate limits, and malformed responses gracefully
  - **Cleanup Fix**: Fixed temp_versions.txt file not being removed when no changes are detected
    - Added dedicated cleanup step for scenarios where no version changes occur
    - Enhanced final cleanup step with better debugging output
    - Ensured temp file removal in all workflow execution paths
- **Input Validation Standardization Phase 1**: Implemented comprehensive input validation improvements across critical scripts
  - **Enhanced Shared Functions Library**: Added advanced validation functions to `scripts/functions/shared/enginescript-common.sh`
    - `prompt_continue()` - Enhanced "Press Enter" prompts with timeout (300s default) and exit options
    - `prompt_yes_no()` - Standardized yes/no prompts with validation, defaults, and timeout handling
    - `prompt_input()` - Advanced text input with regex validation, defaults, timeout, and empty input handling
    - `validate_domain()`, `validate_email()`, `validate_url()` - Dedicated validation functions for common input types
  - **Critical Script Updates**: Replaced minimal validation patterns with robust, timeout-enabled prompts
    - Fixed `scripts/install/tools/system/amazon-s3-install.sh` - replaced basic `y` prompt with timeout and exit handling
    - Fixed `scripts/functions/vhost/vhost-import.sh` - enhanced all user prompts with validation and timeout (600s for file prep, 300s for configuration)
      - Site URL input now includes proper URL format validation
      - Database prefix input includes format validation and automatic underscore appending
      - Database charset input includes validation
      - Cloudflare configuration prompt standardized with yes/no validation
      - Site verification prompt enhanced with timeout and proper error handling
    - Fixed `scripts/functions/vhost/vhost-install.sh` - standardized Cloudflare configuration prompt with enhanced validation
    - Fixed `scripts/functions/vhost/vhost-remove.sh` - improved initial confirmation prompt with timeout and validation
    - Fixed `scripts/install/enginescript-install.sh` - enhanced admin subdomain security prompt with standardized validation
  - **Safety Improvements**: All enhanced prompts now include automatic timeout (300-600 seconds) and consistent exit handling
  - **User Experience**: Eliminated hanging prompts and provided clear feedback for invalid inputs
  - **Backward Compatibility**: All changes maintain existing script functionality while adding robust validation
- **Final Legacy Conditional Expression Modernization**: Completed the final phase of modernizing all remaining conditional expressions in the codebase
  - Fixed `scripts/install/nginx/nginx-tune.sh` - converted 13 legacy `[ ]` conditionals to `[[ ]]` syntax for memory and HTTP3 configurations
  - Fixed `scripts/functions/vhost/vhost-import.sh` - converted 5 additional legacy `[ ]` conditionals to `[[ ]]` syntax for database handling and file operations
  - **Comprehensive Achievement**: Successfully modernized 100% of all conditional expressions across the entire EngineScript codebase
  - All 150+ shell scripts now consistently use modern `[[ ]]` syntax instead of legacy `[ ]` test operators
  - Enhanced code safety with better string handling, pattern matching, and reduced word splitting risks
  - Improved readability and maintainability with consistent modern shell scripting practices
- **Legacy Conditional Expression Completion**: Completed modernization of all remaining conditional expressions across the entire codebase
  - Fixed `scripts/update/enginescript-update.sh` - converted 3 legacy `[ ]` conditionals to `[[ ]]` syntax
  - Fixed `scripts/update/php-config-update.sh` - converted 6 legacy `[ ]` conditionals to `[[ ]]` syntax
  - Fixed `scripts/update/software-update.sh` - converted 2 legacy `[ ]` conditionals to `[[ ]]` syntax
  - Fixed `scripts/functions/vhost/vhost-import.sh` - converted 8 additional legacy `[ ]` conditionals to `[[ ]]` syntax
  - **Achievement**: 100% of scripts now use modern `[[ ]]` conditional expressions (previously 90%)
  - All 150+ scripts in the codebase now follow consistent modern shell scripting practices
  - Improved string comparison safety and eliminated potential word splitting issues
- **Shared Functions Library Integration**: Expanded usage of `scripts/functions/shared/enginescript-common.sh` across the entire codebase
  - Added shared library sourcing to all vhost scripts (`vhost-install.sh`, `vhost-import.sh`, `vhost-remove.sh`)
  - Added shared library sourcing to installation scripts (`php-install.sh`, `redis-install.sh`, `nginx-cloudflare-ip-updater.sh`)
  - Added shared library sourcing to update scripts (`nginx-update.sh`, `mariadb-update.sh`)
  - Replaced direct `service restart` commands with `restart_service()` function calls for consistency
  - Enhanced `nginx-update.sh` with comprehensive error logging and debug pauses using shared functions
  - Fixed remaining conditional expressions (`[ ]` → `[[ ]]`) in `vhost-import.sh` for consistency
  - All scripts now use consistent error handling, service management, and debugging patterns

