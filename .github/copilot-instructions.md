---
applyTo: '**'
---
Coding standards, domain knowledge, and preferences that AI should follow.

# Work Environment

This project is coded entirely in a remote development environment using GitHub Codespaces. The AI will never ask me to run Terminal commands or use a local development environment. All code changes, tests, and debugging will be done within remote repositories on GitHub. 

Change summaries should be concise and clear, focusing on the specific changes made. The AI should not ask for confirmation before making changes, as all code modifications will be done directly in the remote environment. 

# Responses

When delivering responses, the AI should provide clear, concise, and actionable information. Responses should be formatted in a way that is easy to read and understand, with a focus on clarity and precision. The AI should avoid unnecessary verbosity or complexity in its explanations.

Responses, change summaries, and code comments should be written in English. The AI should not use any other languages or dialects, including regional variations of English. All communication should be clear and professional, adhering to standard English grammar and spelling conventions. 

Responses should be delivered only in the chat interface. Formatting and styling should be utilized to enhance readability.

Change summaries should never be created in the form of new .md files.

# Code Analysis and Reading Standards

You must read files completely and thoroughly, with a minimum of 1500 lines per read operation when analyzing code. Never truncate files or stop reading at arbitrary limits like 50 or 100 lines - this lazy approach provides incomplete context and leads to poor suggestions. When you encounter any file, read it from the very first line to the absolute last line, processing all functions, classes, variables, imports, exports, and code structures. Your analysis must be based on the complete file content, not partial snapshots. Always read at least 1000 lines minimum per read operation, and if the file is larger, continue reading until you've processed the entire file. Do not use phrases like "showing first X lines" or "truncated for brevity" or "rest of file omitted" - these indicate lazy, incomplete analysis. Instead, demonstrate that you've read the complete file by referencing specific sections throughout the entire codebase, understanding the full context of how functions interact, how variables are used across the entire file, and how the complete code structure works together. Your suggestions and recommendations must reflect knowledge of the entire file, not just the beginning portions. Take the time to read everything properly because thoroughness and accuracy based on complete file knowledge is infinitely more valuable than quick, incomplete reviews that miss critical context and lead to incorrect suggestions.

# Coding Standards and Preferences

# Coding Standards and Preferences

## EngineScript Project Focus

- This project is a LEMP server installation and configuration script for hosting WordPress sites.
- The project automates the installation and configuration of Ubuntu, Nginx, PHP, MariaDB, and Redis.
- Primary focus is on server administration, shell scripting, and system configuration.
- All scripts are written in Bash and follow Unix/Linux best practices.
- The project creates and manages WordPress installations but is not itself a WordPress plugin or theme.
- Integration with Cloudflare API for DNS management and performance optimization.
- Focus on security, performance, and automation for WordPress hosting environments.

## Shell Scripting Standards

- Follow standard Bash scripting best practices and conventions.
- Use proper error handling with `set -e` and appropriate exit codes.
- Validate all user inputs and handle edge cases gracefully.
- Use meaningful variable names in UPPER_CASE for global variables and lower_case for local variables.
- Include proper shebang lines (`#!/usr/bin/env bash`) in all scripts.
- Use proper quoting to prevent word splitting and glob expansion issues.
- Include comprehensive error checking for all system commands.
- Follow the principle of least privilege - run commands with minimal required permissions.
- Use functions to organize code and avoid repetition.
- Include proper logging and user feedback throughout installation processes.

## System Administration Standards

- Ensure compatibility with Ubuntu 24.04 LTS (primary) and Ubuntu 22.04 LTS (supported).
- Follow Linux Filesystem Hierarchy Standard (FHS) for file placement.
- Use systemd for service management and configuration.
- Implement proper backup and restoration procedures.
- Follow security best practices for server hardening.
- Use secure methods for handling sensitive data (passwords, API keys, etc.).
- Implement proper file permissions and ownership.
- Ensure all configurations are production-ready and secure by default.

## Software Version Management

- Track current versions of all major software components:
  - Nginx (compiled from source with custom optimizations)
  - PHP (latest stable version)
  - MariaDB (latest LTS version)
  - Redis (latest stable version)
  - OpenSSL (latest stable version)
  - Various WordPress tools (WP-CLI, Wordfence CLI, etc.)
- Maintain compatibility matrices for supported software combinations.
- Implement version checking and update mechanisms.
- Document minimum and recommended system requirements.

## Supported Software Versions

- This project supports modern server software versions:
  - Ubuntu 24.04 LTS (primary) and Ubuntu 22.04 LTS (supported)
  - Nginx (latest mainline, compiled from source)
  - PHP 8.4+ (latest stable recommended)
  - MariaDB 11.8+ (latest LTS recommended)
  - Redis (latest stable)
  - WordPress 6.5+ (when installing WordPress sites)
- Do not use features or functions that are not available in the minimum supported versions.
- Always verify compatibility when introducing new software dependencies.

## Documentation and Change Tracking

- This project does not use traditional release versioning but tracks changes through continuous improvement.
- Always document changes in the CHANGELOG.md file when making modifications to the codebase.
- Documentation locations that should be kept updated:
  - README.md (main project documentation)
  - CHANGELOG.md (change tracking and development history)
  - Individual script headers and comments
  - Configuration file templates and examples
  - GitHub workflow files and documentation
- Use clear, descriptive commit messages that explain the purpose and scope of changes.
- Group related changes logically in the changelog under descriptive headings.
- Document any new dependencies, system requirements, or breaking changes prominently.
- When making significant changes, update relevant documentation files simultaneously.
- Include installation, configuration, and troubleshooting information in documentation.
- Document any manual steps required after script updates or system changes.

# General Coding Standards

- The above standards are prioritized over general coding standards.
- The standards below are general coding standards that apply to all code, including WordPress code. Do not apply them if they conflict with WordPress standards.

## Accessibility & UX

- Follow accessibility best practices for UI components
- Ensure forms are keyboard-navigable and screen reader friendly
- Validate user-facing labels, tooltips, and messages for clarity

## Performance & Optimization

- Optimize for performance and scalability where applicable
- Avoid premature optimization—focus on correctness first
- Detect and flag performance issues (e.g., unnecessary re-renders, N+1 queries)
- Use lazy loading, memoization, or caching where needed

## Type Safety & Standards

- Use strict typing wherever possible (TypeScript, C#, etc.)
- Avoid using `any` or untyped variables
- Use inferred and narrow types when possible
- Define shared types centrally (e.g., `types/` or `shared/` folders)

## Security & Error Handling

- Sanitize all input and output, especially in configuration files and user-provided data.
- Validate and normalize all user-supplied configuration values.
- Automatically handle edge cases and error conditions in installation scripts.
- Fail securely and log actionable errors with appropriate detail levels.
- Avoid leaking sensitive information (passwords, API keys, server details) in error messages or logs.
- Use secure coding practices to prevent common vulnerabilities in server environments.
- Implement proper file permissions and ownership throughout the system.
- Use secure methods for storing and transmitting sensitive configuration data.
- When using third-party packages or repositories, ensure they are well-maintained and from trusted sources.
- Regularly update software dependencies to their latest stable versions.
- Use HTTPS for all external API requests and package downloads.
- When handling sensitive data (database passwords, API keys), ensure proper encryption and access controls.
- If you suspect a security vulnerability, immediately notify the project maintainers.
- If you encounter a security vulnerability in the codebase, do not disclose it publicly.
- Always follow the principle of least privilege when configuring system services and user permissions.
- If you encounter a security vulnerability in system packages or dependencies, document it and provide guidance for mitigation.
- If there is a possible security vulnerability in server configurations, always ask for confirmation before proceeding.
- Server hardening and security configurations should be thoroughly tested before implementation.

## Code Quality & Architecture

- Organize shell scripts using modular, function-based architecture.
- Group related functionality together (e.g., installation scripts, configuration scripts, utility functions).
- Write clean, readable, and well-documented shell scripts.
- Use meaningful and descriptive names for scripts, functions, and variables.
- Remove unused variables, functions, and dead code automatically.
- Follow consistent coding patterns throughout the project.
- Use proper indentation and formatting for shell scripts.
- Include comprehensive inline documentation and comments.
- Implement error checking and validation for all critical operations.
- Use configuration files and templates to maintain separation of concerns.

## Task Execution & Automation

- Always proceed to the next task automatically unless confirmation is required.
- Only ask for confirmation when an action could affect system stability or security.
- Always attempt to identify and fix bugs automatically in shell scripts.
- Only ask for manual intervention if system-specific knowledge is required.
- Auto-generate missing configuration files and templates when possible.
- Use appropriate shell script linting and validation tools.
- Changes should be made directly to the script files when possible.
- New scripts may be created when appropriate, but should follow the existing project structure.
- Avoid unnecessary duplication of functionality across scripts.
- Ensure all changes maintain backward compatibility unless explicitly breaking changes are required.