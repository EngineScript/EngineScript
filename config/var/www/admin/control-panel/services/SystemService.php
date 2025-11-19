<?php
/**
 * SystemService
 * System information service layer
 * 
 * @version 1.0.0
 */

class SystemService {
    
    /**
     * Get OS information
     * @return string OS information
     */
    public static function getOsInfo() {
        $os_release = file_get_contents('/etc/os-release');
        if ($os_release && preg_match('/PRETTY_NAME="([^"]+)"/', $os_release, $matches)) {
            return $matches[1];
        }
        return 'Unknown Linux Distribution';
    }
    
    /**
     * Get kernel version
     * @return string Kernel version
     */
    public static function getKernelVersion() {
        try {
            $version = SystemCommand::getKernelVersion();
            if ($version !== null) {
                $version = trim($version);
                if (preg_match('/^[0-9]+\.[0-9]+\.[0-9]+/', $version)) {
                    return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                }
            }
        } catch (Exception $e) {
            error_log('Kernel version error: ' . $e->getMessage());
        }
        return 'Unknown';
    }
    
    /**
     * Get network information
     * @return string Network information (hostname and IP)
     */
    public static function getNetworkInfo() {
        try {
            $hostname = gethostname();
            if ($hostname === false) {
                $hostname = 'Unknown';
            }
            
            if ($hostname !== 'Unknown') {
                $hostname = htmlspecialchars($hostname, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
            
            $client_ip = 'Unknown';
            
            if (file_exists('/proc/net/route')) {
                $ip_output = SystemCommand::getNetworkIP();
                if ($ip_output !== null) {
                    $client_ip = trim($ip_output);
                    if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
                        $client_ip = 'Unknown';
                    }
                    
                    if ($client_ip !== 'Unknown') {
                        $client_ip = htmlspecialchars($client_ip, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                    }
                }
            }
            
            return $hostname . ' (' . $client_ip . ')';
        } catch (Exception $e) {
            error_log('Network info error: ' . $e->getMessage());
            return 'Unknown (Unknown)';
        }
    }
}
