# Changelog

All notable changes to EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

## 2025-06-27

### Added
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

### Changed
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

### Fixed
- GitHub Actions workflow SSE plugin version checking issues
- Improved temp file cleanup handling in automated workflows
- Redis memory monitoring thresholds in cleanup scripts
- Software version checking now properly handles "null" plugin versions and will update them to latest releases
- YAML syntax errors in nginx-compilation-test.yml workflow caused by heredoc (EOF) formatting
- Ubuntu version matrix in nginx-compilation-test.yml to use only Ubuntu 24.04 for consistency
- Artifact naming in nginx-compilation-test.yml to reflect single Ubuntu version support
- Nginx configuration file creation using proper YAML-compatible heredoc syntax

### Security
- Enhanced CPU feature validation in compilation scripts
- Improved input validation for user-configurable CPU architecture settings

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
