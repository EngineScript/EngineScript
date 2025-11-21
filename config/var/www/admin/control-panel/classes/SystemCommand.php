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
     * @param string $service Service name (validated, alphanumeric + dash/underscore/dot)
     * @return string|false Service status (active/inactive) or false on error
     */
    public static function getServiceStatus($service) {
        // Validate service name (alphanumeric, dash, underscore, dot only)
        // Dot added to support PHP-FPM services like php-fpm8.4
        if (!preg_match('/^[a-zA-Z0-9._-]+$/', $service)) {
            return false;
        }
        
        // @codacy suppress [The use of function escapeshellarg() is discouraged] Required for shell command safety - input is validated
        $command = sprintf('systemctl status %s --no-pager 2>/dev/null', escapeshellarg($service));
        $output = self::execute($command);
        
        if ($output === false || empty($output)) {
            return false;
        }
        
        // Parse the Active line from systemctl status output
        // Format: "     Active: active (running) since ..."
        if (preg_match('/Active:\s+(active|inactive|failed|unknown)/', $output, $matches)) {
            return $matches[1];
        }
        
        return false;
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
