# Changelog

All notable changes to EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

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
