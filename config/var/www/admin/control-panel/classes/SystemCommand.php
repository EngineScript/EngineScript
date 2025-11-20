<?php
/**
 * SystemCommand Class
 * Encapsulates all shell command executions for security, testing, and maintainability
 * 
 * @version 1.0.0
 * @security HIGH - Centralized command execution with validation
 */

class SystemCommand {
    
    /**
     * Execute a shell command with validation and error handling
     * @param string $command The command to execute
     * @return string|false Command output or false on failure
     */
    private static function execute($command) {
        if (empty($command)) {
            return false;
        }
        
        // For testing environments, we can mock this
        if (defined('ENGINESCRIPT_MOCK_SHELL') && ENGINESCRIPT_MOCK_SHELL) {
            return self::mockCommand();
        }
        
        // Execute command
        $output = shell_exec($command);
        
        return $output !== null ? trim($output) : false;
    }
    
    /**
     * Mock command execution for testing
     * @return string Mocked output
     */
    private static function mockCommand() {
        // Testing hook - can be extended for unit tests
        return '';
    }
    
    /**
     * Get systemd services
     * @return string Raw systemctl output
     */
    public static function getSystemdServices() {
        $command = 'systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null';
        return self::execute($command);
    }
    
    /**
     * Get kernel version
     * @return string Kernel version or empty string
     */
    public static function getKernelVersion() {
        return self::execute('uname -r 2>/dev/null');
    }
    
    /**
     * Get primary network IP address
     * @return string IP address or empty string
     */
    public static function getNetworkIP() {
        $command = "ip route get 8.8.8.8 2>/dev/null | awk '{print \$7; exit}'";
        return self::execute($command);
    }
    
    /**
     * Get service status
     * @param string $service Service name (validated, alphanumeric + dash only)
     * @return string Service status output
     */
    public static function getServiceStatus($service) {
        // Validate service name (alphanumeric, dash, underscore only, and dots)
        if (!preg_match('/^[a-zA-Z0-9_\.\-]+$/', $service)) {
            return false;
        }
        
        // @codacy suppress [The use of function escapeshellarg() is discouraged] Required for shell command safety - input is validated
        $command = sprintf('systemctl status %s --no-pager 2>/dev/null', escapeshellarg($service));
        return self::execute($command);
    }
    
    /**
     * Check if service is active (lightweight check)
     * @param string $service Service name (validated)
     * @return bool True if active, false otherwise
     */
    public static function isServiceActive($service) {
        // Validate service name (alphanumeric, dash, underscore only, and dots)
        if (!preg_match('/^[a-zA-Z0-9_\.\-]+$/', $service)) {
            return false;
        }
        
        // @codacy suppress [The use of function escapeshellarg() is discouraged] Required for shell command safety - input is validated
        $command = sprintf('systemctl is-active %s 2>/dev/null', escapeshellarg($service));
        $output = self::execute($command);
        return $output === 'active';
    }
    
    /**
     * Get Nginx version
     * @return string Nginx version output
     */
    public static function getNginxVersion() {
        return self::execute('nginx -v 2>&1');
    }
    
    /**
     * Get PHP version
     * @return string PHP version output
     */
    public static function getPhpVersion() {
        return self::execute('php -v 2>/dev/null');
    }
    
    /**
     * Get MariaDB version
     * @return string MariaDB version output
     */
    public static function getMariadbVersion() {
        return self::execute('mariadb --version 2>/dev/null');
    }
    
    /**
     * Get Redis version
     * @return string Redis version output
     */
    public static function getRedisVersion() {
        return self::execute('redis-server --version 2>/dev/null');
    }
}
