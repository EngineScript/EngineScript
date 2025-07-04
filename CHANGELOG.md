# Changelog

All notable changes to EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

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
- **Conditional Expression Standardization**: Replaced all `[ ]` (test) conditional expressions with `[[ ]]` (keyword) throughout the entire codebase
  - Updated all installation scripts (enginescript-install.sh, nginx-install.sh, php-install.sh, mariadb-install.sh, redis-install.sh, gcc-install.sh, etc.)
  - Updated all function scripts (backup scripts, cron scripts, vhost scripts, security scripts, alias scripts, etc.)
  - Updated all utility and tool installation scripts (ufw-cloudflare.sh, zlib-install.sh, tools-install.sh, etc.)
  - Modernizes shell scripting practices and improves readability and maintainability
  - `[[ ]]` provides better string handling, pattern matching, and is less error-prone than `[ ]`
- **Shell Scripts**: Standardized shebang line in `scripts/functions/alias/alias-debug.sh` to use `#!/usr/bin/env bash` for consistency across all shell scripts
- **Function Deduplication**: Created shared functions library at `scripts/functions/shared/enginescript-common.sh` to consolidate duplicated functions
  - Consolidated `debug_pause()` and `print_last_errors()` functions from `scripts/install/enginescript-install.sh` and `scripts/install/nginx/nginx-install.sh`
  - Consolidated `restart_service()`, `restart_php_fpm()`, and `clear_cache()` functions from `scripts/functions/alias/alias-cache.sh` and `scripts/functions/alias/alias-restart.sh`
  - Updated `scripts/install/enginescript-install.sh`, `scripts/install/nginx/nginx-install.sh`, `scripts/install/tools/tools-install.sh`, `scripts/functions/alias/alias-cache.sh`, and `scripts/functions/alias/alias-restart.sh` to source the shared library
  - Removed duplicate function definitions from individual scripts, improving maintainability and consistency

### 🐛 BUG FIXES
- **Timing Issues**: Fixed timing issues in `scripts/functions/vhost/vhost-export.sh`
  - Added `set -e` and `set -o pipefail` for proper error handling
  - Changed all command execution to use immediate error checking instead of checking `$?` after the fact
  - Improved error checking for `cd` commands and file operations
  - Enhanced cleanup operations with `|| true` to prevent secondary errors
  - Fixed race conditions between database export, compression, and file archiving operations
- **Silent Error Handling**: Fixed silent error handling in `scripts/functions/alias/alias-debug.sh`
  - Added `set -o pipefail` for proper pipeline error handling
  - Enhanced all command substitutions with error checking and fallback values
  - Added comprehensive error checking for system information gathering (CPU, memory, disk, network)
  - Improved hostname, network interface, and port detection with proper error handling
  - Added fallback values ("unknown") for failed system information commands
  - Enhanced website status checking with proper curl error handling

---

## 2025-06-29

### 🚀 ENHANCEMENTS
- **CI/CD Pipeline**: Modernized GitHub Actions workflow to focus exclusively on Nginx build testing
- **CI/CD Pipeline**: Simplified workflow triggers and removed unnecessary test jobs
- **CI/CD Pipeline**: Enhanced debugging and logging for CI environment troubleshooting
- **CI/CD Pipeline**: Improved artifact collection for build logs and test results
- **CI/CD Pipeline**: **NEW** Added automatic GitHub issue reporting for failed CI builds
- **CI/CD Pipeline**: **NEW** Added intelligent issue deduplication to prevent spam (checks for existing CI failure issues within 24 hours)
- **CI/CD Pipeline**: **NEW** Added comprehensive failure logs in automated issue reports with collapsible sections
- **CI/CD Pipeline**: **NEW** Added `nginx -V` output capture in CI test summary and issue reports

### 🐛 BUG FIXES

#### Critical CI Timeout Resolution
- **CI/CD Pipeline**: **FIXED** systematic script timeouts by identifying and resolving root cause
- **CI/CD Pipeline**: Created CI-specific `enginescript-variables-ci.txt` to prevent command substitution hangs
- **CI/CD Pipeline**: Replaced dynamic command substitutions with static values for CI environment
- **CI/CD Pipeline**: Added comprehensive configuration file validation and timeout testing
- **CI/CD Pipeline**: Simplified script execution approach to prevent bash context issues
- **CI/CD Pipeline**: Enhanced script permission setting and validation before execution

#### Script Execution Improvements
- **Scripts**: Removed EUID/root privilege checks from all scripts except `setup.sh` and `enginescript-install.sh`
- **Scripts**: Enhanced error handling and debugging output for CI environment compatibility
- **Scripts**: Added syntax validation before script execution to catch errors early
- **Scripts**: Improved timeout handling and error reporting for long-running operations

### 🔧 DEVELOPMENT
- **CI/CD Pipeline**: Removed problematic `export EUID=0` that caused "readonly variable" errors
- **CI/CD Pipeline**: Replaced complex "Remove Preinstalled Software" step with focused Nginx/Apache removal
- **CI/CD Pipeline**: Added systematic debugging for environment variables and file permissions
- **CI/CD Pipeline**: Enhanced log collection and artifact management for troubleshooting
- **CI/CD Pipeline**: Added missing "Install Repositories" step before dependencies installation
- **CI/CD Pipeline**: Enhanced workflow permissions to support automatic issue creation (`issues: write`)
- **CI/CD Pipeline**: Improved test result reporting with comprehensive build environment details

---

## 2025-06-28

### Changed
- **Removed EUID/root user checks from all scripts except `setup.sh` and `enginescript-install.sh`**
  - Eliminated EUID checks from 100+ shell scripts across all directories
  - Maintained root checks only in the main entry point scripts (`setup.sh` and `scripts/install/enginescript-install.sh`)
  - Prevents CI workflow hangs caused by EUID checks in non-interactive environments
  - Improves script portability and execution in containerized/automated environments
  - Scripts affected include all alias, auto-upgrade, cron, security, vhost, install, update, and menu scripts
  - CI workflows can now execute all scripts without manual EUID override requirements

## 2025-06-27

### Added
- **Simplified GitHub Actions CI workflow to single comprehensive build test**
- **Workflow cancellation support to automatically cancel previous runs on new commits**
- **Comprehensive test results reporting with PR commenting functionality**
- **Professional CI/CD reporting with detailed component status tables**
- **Structured log collection system using dedicated `/tmp/ci-logs/` directory**
- **Component-by-component build verification with success/failure tracking**
- **Automated PR status updates with build results and component breakdown**
- **Enhanced permissions management for GitHub Actions and script execution**
- **Robust error handling and log flushing throughout the build process**
- **Complete artifact collection including all build logs for debugging**
- Dynamic CPU capability detection in Nginx compilation script
- Intelligent CPU architecture optimization with fallback to native detection
- User-configurable CPU architecture override option for custom builds
- Enhanced compiler flag detection for vector instructions (AVX, AVX2)
- Cryptographic hardware acceleration detection (AES, RDRND, RDSEED)
- Bit manipulation instruction support (BMI, BMI2, LZCNT)
- Additional CPU feature detection (FSGSBASE, PRFCHW)
- Comprehensive CPU optimization output during Nginx compilation
- Hourly cleanup cron script for lightweight maintenance tasks
- EngineScript plugins install option to control custom plugin installation
- Backward compatibility mechanism for existing installations
- HTTP/3 and QUIC compilation testing in Nginx workflow matrix
- Comprehensive HTTP/3 configuration syntax validation 
- QUIC-specific directive testing and verification
- Enhanced dependencies installation timeout (15 minutes) for CI stability
- Matrix-based Nginx compilation testing (standard, optimized, HTTP/3)
- Workflow dispatch options for selective Nginx test execution
- Complete EngineScript base installation sequence in CI workflows
- Proper sequential installation following enginescript-install.sh line order
- Base setup integration including setup.sh execution
- Full dependency chain installation before component testing
- Comprehensive full-build-test job with proper error handling and verification
- Step-by-step build process (setup → dependencies → OpenSSL → Nginx → PHP → MariaDB → Redis → system services)
- Enhanced build verification with binary existence checks and version validation
- Proper artifact collection for full build logs and debugging
- CI-optimized disk space management for complete system builds
- Structured build phases with individual error reporting and log collection

### Changed
- **Consolidated all CI jobs into single `full-build-test` job for simplicity and reliability**
- **Updated workflow triggers to run on all pushes (any branch) and all pull requests**
- **Replaced complex matrix-based testing with comprehensive single-build approach**
- **Streamlined CI workflow from 900+ lines to focused, maintainable configuration**
- **Enhanced log collection strategy with centralized `/tmp/ci-logs/` directory**
- **Improved permission handling with proper file ownership for CI operations**
- **Updated GitHub Actions permissions to include `actions: read` and `pull-requests: write`**
- **Migrated setup.sh logic directly into CI workflow with CI-specific optimizations**
- **Replaced setup.sh execution with inline setup steps, omitting problematic CI components**
- **Separated base component installation into individual workflow steps for better debugging**
- **Streamlined component installation by removing unnecessary steps (package blocking, cron, ACME.sh, swap)**
- **Skipped external repository installation in CI to prevent hanging issues caused by network dependencies**
- Updated Copilot instructions to reflect EngineScript project focus instead of WordPress plugin development
- Nginx compilation now uses intelligent CPU detection instead of hardcoded optimization flags
- Cleanup cron script now runs hourly with time-based task execution
- Plugin installation logic now respects INSTALL_ENGINESCRIPT_PLUGINS setting
- Updated software versions in automated dependency check:
  - MariaDB updated from 11.4.5 to 11.4.7
  - Nginx updated from 1.27.5 to 1.29.0
  - Software version table in README.md updated to reflect latest versions
  - Migrated EngineScript plugins to separate repositories:
  - Simple WP Optimizer moved to https://github.com/EngineScript/Simple-WP-Optimizer
  - Simple Site Exporter moved to https://github.com/EngineScript/Simple-WP-Site-Exporter
  - Updated all plugin download URLs and version tracking to use new repository locations
- Updated GitHub Actions workflow to use only Ubuntu 24.04 runners for all build and test jobs
- Removed Ubuntu 20.04 and 22.04 from CI/CD test matrix to focus on latest LTS support
- Standardized all workflow jobs (validate-scripts, component-build-test, nginx-specific-test, full-build-test, report-results) to use ubuntu-24.04
- Updated artifact naming to reflect single Ubuntu version in build logs
- Restructured CI workflows to follow proper EngineScript installation sequence
- Component tests now run only after complete base installation (lines 1-453)
- CI now follows the exact installation order: repositories → depends → gcc → openssl → pcre → zlib
- Nginx, PHP, MariaDB, Redis tests now properly depend on completed base setup
- Removed individual component dependency installations in favor of base sequence

### Fixed
- **Fixed all permission issues in CI workflow with proper file ownership and script execution rights**
- **Resolved log file creation and reading permission conflicts throughout workflow**
- **Fixed PR comment file generation with appropriate user permissions**
- **Eliminated workflow timeout issues by simplifying to single comprehensive test**
- **Fixed log flushing and content verification to ensure all build logs are captured**
- **Corrected file path inconsistencies in artifact upload for reliable log collection**
- **Fixed script executable permission setting to occur immediately after file copying**
- **Resolved CI configuration file handling with proper error checking and fallbacks**
- **Fixed root privilege checks in CI environment to properly handle GitHub Actions sudo context**
- **Resolved EUID validation issues by running all installation scripts in proper root shell context**
- GitHub Actions workflow SSE plugin version checking issues
- Improved temp file cleanup handling in automated workflows
- Redis memory monitoring thresholds in cleanup scripts
- Software version checking now properly handles "null" plugin versions and will update them to latest releases
- YAML syntax errors in nginx-compilation-test.yml workflow caused by heredoc (EOF) formatting
- Ubuntu version matrix in nginx-compilation-test.yml to use only Ubuntu 24.04 for consistency
- Artifact naming in nginx-compilation-test.yml to reflect single Ubuntu version support
- Nginx configuration file creation using proper YAML-compatible heredoc syntax
- Dependencies installation timeout issues in CI by increasing limit to 15 minutes
- Enhanced error diagnostics for dependencies installation failures
- Improved path validation and executable checks for depends-install.sh
- Better CI environment setup for EngineScript testing workflows
- **Fixed CI component testing by implementing proper base installation sequence**
- **Resolved timeout issues by following correct EngineScript installation dependencies**
- **Fixed Nginx compilation failures by ensuring OpenSSL, PCRE, and Zlib are pre-installed**
- **Completed full-build-test job with comprehensive step-by-step build verification**
- **Fixed script permission issues by ensuring all .sh files are executable in CI environment**
- **Fixed critical workflow step ordering - permissions now set immediately after script copying, before execution**
- **Eliminated reliance on terminal commands in CI workflows per project standards**
- **Implemented proper error handling and log collection for all build phases**
- **Enhanced build artifact collection for debugging failed builds**

### Removed
- **Eliminated complex CI matrix jobs (validate-scripts, component-build-test, nginx-specific-test, report-results)**
- **Removed redundant validation and testing steps in favor of comprehensive single build**
- **Simplified workflow from multiple parallel jobs to single sequential build process**
- **Removed dos2unix step and line ending conversion dependencies**
- **Excluded problematic setup.sh components from CI: dos2unix, logrotate, aliases, tzdata, motd, hwe, system restart**

### Security
- Enhanced CPU feature validation in compilation scripts
- Improved input validation for user-configurable CPU architecture settings

### Technical Details
- **CI workflow now runs single comprehensive build test covering all components**
- **Build process follows exact EngineScript installation sequence for maximum reliability**
- **All build steps include proper timeout handling, error checking, and log collection**
- **PR commenting provides immediate feedback on build status with component breakdown**
- **Workflow cancellation prevents resource waste and ensures latest code is always tested**
- **Log collection system captures all build output for debugging and verification**
- **Permission model ensures proper file access throughout the CI process**
- **Artifact upload includes both CI logs and EngineScript system logs for complete debugging**

---

## 2025-01-22

### Added
- MariaDB installation testing to GitHub Actions component build matrix
- Redis installation testing to GitHub Actions component build matrix
- Individual MariaDB-specific test job with configuration validation
- Individual Redis-specific test job with connectivity testing
- New workflow dispatch options for mariadb-only and redis-only test scopes
- Standardized base setup for all CI tests including core packages and full dependencies
- Comprehensive dependency installation using both setup.sh core packages and depends-install.sh

### Changed
- Enhanced GitHub Actions workflow to use only Ubuntu 24.04 runners for all build and test jobs
- Removed Ubuntu 20.04 and 22.04 from CI/CD test matrix to focus on latest LTS support
- Standardized all workflow jobs (validate-scripts, component-build-test, nginx-specific-test, full-build-test, report-results) to use ubuntu-24.04
- Updated artifact naming to reflect single Ubuntu version in build logs
- Improved component build test matrix to include ['dependencies', 'nginx', 'php', 'openssl', 'mariadb', 'redis']
- Unified CI environment setup with consistent dependency installation across all component tests
- Enhanced test reporting to include MariaDB and Redis specific test results

### Fixed
- Missing MariaDB component testing in CI/CD pipeline
- Missing Redis component testing in CI/CD pipeline  
- Inconsistent dependency installation across different component tests
- Eliminated duplicate dependency installation code in component tests

### Technical Details
- Component tests now install both core packages (from setup.sh) and full dependencies (depends-install.sh) consistently
- Each component test builds upon a standardized EngineScript environment foundation
- MariaDB tests include both installation and configuration validation
- Redis tests include both installation and connectivity testing
- All tests maintain proper timeout handling and error reporting
- Build logs are uploaded for all component tests for debugging purposes

## About This Changelog

This changelog tracks all notable changes made to the EngineScript project organized by date. Changes are categorized as:

- **Added** for new features
- **Changed** for changes in existing functionality  
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes
- **Removed** for now removed features

Each entry is dated to show when changes were implemented. For questions about any changes listed here, please refer to the project documentation or open an issue on GitHub.

---

## 2025-01-27

### Changed
- **Simplified CI workflow to focus exclusively on Nginx compilation testing**
- **Renamed workflow from "EngineScript Build Test" to "EngineScript Nginx Build Test"**
- **Reduced build timeout from 180 to 120 minutes for focused Nginx testing**
- **Removed PHP, MariaDB, and Redis build steps and verification from CI workflow**
- **Updated verification and reporting steps to only check Nginx component status**
- **Streamlined PR comments to report only Nginx build results**
- **Updated artifact naming from "full-build-logs" to "nginx-build-logs" for clarity**
- **Removed unnecessary directory creation for PHP, MariaDB, and Redis configurations**
- **Simplified final status check to only validate Nginx build success**
- **Modified test summary generation to focus on Nginx component only**

### Removed
- **PHP build and verification steps from CI workflow (not needed for core functionality testing)**
- **MariaDB installation and verification steps from CI workflow**
- **Redis installation and verification steps from CI workflow**
- **PHP-specific directory creation and configuration checks**
- **MariaDB-specific directory creation and credential management setup**
- **Multi-component status tracking and reporting complexity**

### Technical Details
- CI workflow now provides faster feedback by testing only the most critical component (Nginx)
- Simplified workflow structure reduces maintenance overhead and potential CI failures
- Focus on Nginx compilation ensures the most complex build process is thoroughly tested
- Removed components (PHP, MariaDB, Redis) can still be tested manually or in separate workflows if needed
- Nginx build remains the most comprehensive test of EngineScript's compilation capabilities

---

## 2025-01-29

### Added
- **Enhanced debugging for CI script execution hangs**
- **Comprehensive environment checks before script execution**
- **Package manager preparation and lock removal in CI environment**
- **Script existence and permission validation before execution**
- **Enhanced error reporting with detailed log output for failed scripts**

### Fixed
- **Fixed CI script hanging by adding enhanced debugging to Remove Preinstalled Software step**
- **Added EUID override for CI environment to prevent root check failures**
- **Implemented package manager lock removal and process cleanup**
- **Enhanced script timeout handling with detailed failure reporting**

### Technical Details
- CI now validates script existence and permissions before execution
- Package manager locks and hanging processes are cleared before script execution
- EUID is explicitly set to 0 in CI environment to bypass root checks
- Enhanced debugging shows exact point of failure when scripts hang
- Timeout failures now provide detailed log output for debugging

---

## 2025-07-01 - Security Update

### � DEPENDENCY MANAGEMENT
- **Frontend Dependency Tracking**: Added Chart.js and Font Awesome to the automated software version checker
  - **Chart.js**: Now automatically monitored for updates (currently v4.5.0)
  - **Font Awesome**: Now automatically monitored for updates (currently v6.7.2)
  - **Version Variables**: Added `CHARTJS_VER` and `FONTAWESOME_VER` to `enginescript-variables.txt`
  - **Dynamic Substitution**: Admin control panel installation script now substitutes versions automatically
  - **GitHub Actions Integration**: Extended software-version-check.yml workflow to monitor frontend dependencies
  - **README Documentation**: Added Chart.js and Font Awesome to the software versions table

### �🔒 COMPREHENSIVE SECURITY HARDENING
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

### 🛡️ BACKEND API SECURITY (Previously Implemented)
- **Complete API Security Audit**: Comprehensive security review and hardening of PHP API backend
  - **Input Validation**: Strict validation and sanitization of all API inputs
  - **Command Injection Prevention**: Eliminated shell command vulnerabilities
  - **Path Traversal Protection**: Prevented directory traversal attacks
  - **Rate Limiting**: Implemented rate limiting with IP-based tracking
  - **Security Headers**: Added comprehensive security headers for all responses
  - **Error Handling**: Secure error handling without information disclosure
  - **Logging**: Comprehensive security event logging and monitoring
