---
applyTo: '**'
---

# BEHAVIOR RULES

## Complete Code Analysis - No Shortcuts

- Read files completely and thoroughly before making changes
- Understand complete context: how functions interact, variables used across entire file

## Communication Standards

- Provide clear, concise, actionable information
- Use formatting and styling to enhance readability
- Change summaries should be concise, focusing on specific changes made

# PROJECT STANDARDS

## EngineScript - LEMP Server Automation

- **Primary Purpose**: LEMP server installation and configuration script for hosting WordPress sites
- **Core Stack**: Ubuntu 24.04 LTS + Nginx + PHP 8.4+ + MariaDB 11.8+ + Redis
- **Focus Areas**: Server administration, shell scripting, system configuration, security hardening
- **Integration**: Cloudflare API for DNS management and performance optimization
- **Target**: Production-ready WordPress hosting environments with automation and performance

## Shell Scripting Requirements

- All scripts written in **Bash** following Unix/Linux best practice
- Variable naming: `UPPER_CASE` for globals, `lower_case` for locals
- Include shebang lines: `#!/usr/bin/env bash` (standard bash shebang)
- Proper quoting to prevent word splitting and glob expansion
- Comprehensive logging and user feedback during installation

## System Compatibility & Standards

- **Architecture**: Follow Linux Filesystem Hierarchy Standard (FHS)
- **Service Management**: systemd for all service configuration
- **Security**: Production-ready configurations, secure by default, principle of least privilege

## Security & Data Handling (Critical)

- **Input Validation**: Sanitize all input/output, especially user-provided configuration data
- **Sensitive Data**: Use secure methods for passwords, API keys - no leaking in logs/errors
- **External Resources**: Use HTTPS for API requests, ensure third-party packages are trusted

## Documentation & Change Tracking

- **CHANGELOG.md**: Always document changes when modifying codebase (continuous improvement model)
- **Key Files**: Keep updated: README.md, script headers, configuration templates
- **Breaking Changes**: Document new dependencies, system requirements prominently
- **Manual Steps**: Document any required manual steps after updates

## Code Quality & Architecture

- **Modular Design**: Function-based architecture, group related functionality
- **Naming**: Meaningful, descriptive names for scripts, functions, variables
- **Error Handling**: Comprehensive validation, inline error checking, proper exit codes
- **Clean Code**: Remove unused code automatically, consistent patterns
- **Separation**: Use configuration files and templates appropriately
- **Backward Compatibility**: Maintain unless explicitly breaking changes required
- **Logging**: Actionable errors with appropriate detail levels
- **Dependencies**: Verify compatibility when introducing new software
