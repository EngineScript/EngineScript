<?php
/**
 * EngineScript External Services API
 * Handles feed parsing and service status fetching for external services monitoring
 * 
 * @version 1.0.0
 * @security HIGH - Implements strict whitelisting and input validation
 */

// Security: Prevent direct access
if (!defined('ENGINESCRIPT_DASHBOARD')) {
    http_response_code(403);
    // @codacy suppress [Use of die language construct is discouraged] Required for security - unauthorized access prevention
    die('Direct access forbidden');
}

// Load centralized API response handler
// @codacy suppress [require_once statement detected] Secure class loading with __DIR__ constant - no user input
require_once __DIR__ . '/../classes/ApiResponse.php';

/**
 * External Services Feed Parser
 * 
 * Parses RSS/Atom feeds and JSON APIs to determine
 * external service operational status.
 * 
 * @package EngineScript\Dashboard\ExternalServices
 * @version 2.0.0
 * @security HIGH - Implements strict whitelisting and input validation
 */
class ExternalServicesFeedParser
{
    /**
     * Sanitize text from external feeds to prevent injection attacks
     * @param string $text Raw text from feed
     * @return string Sanitized text safe for output
     */
    private static function sanitizeFeedText(string $text): string
    {
    // Convert HTML entities to characters first (handles &lt; &gt; etc)
    // @codacy suppress [The use of function html_entity_decode() is discouraged] Required to decode HTML entities from external feeds before sanitization
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    
    // Strip all HTML tags
    $text = strip_tags($text);
    
    // Remove null bytes (can cause SQL injection in some contexts)
    $text = str_replace("\0", '', $text);
    
    // Normalize whitespace
    $text = preg_replace('/\s+/', ' ', $text);
    
    // Trim
    $text = trim($text);
    
    // Re-encode special characters for safe JSON output
    $text = htmlspecialchars($text, ENT_QUOTES | ENT_HTML5, 'UTF-8', false);
    
    return $text;
}

    /**
     * Parse RSS/Atom feed and extract status information
     * @param string $feedUrl The URL of the RSS/Atom feed
     * @param string|null $filter Optional filter to match specific service name in feed items
     * @return array Status information with indicator and description
     */
    public function parseStatusFeed(string $feedUrl, ?string $filter = null): array
    {
    try {
        // Fetch feed content via cURL with SSL verification
        // codacy:ignore - curl functions required for secure outbound HTTP in standalone API
        $curl = curl_init();
        curl_setopt_array($curl, [
            CURLOPT_URL => $feedUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER => [
                'User-Agent: EngineScript-StatusMonitor/1.0'
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0
        ]);

        $feedContent = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);

        if ($feedContent === false || $httpCode !== 200) {
            throw new Exception('Failed to fetch feed');
        }
        
        // Suppress XML errors and parse securely
        libxml_use_internal_errors(true);
        
        // XXE Protection for PHP 8.0+
        // libxml_disable_entity_loader() was deprecated in PHP 8.0 and removed in PHP 8.2
        // Instead, we use LIBXML_NONET flag to prevent network access during parsing
        // Combined with not using LIBXML_NOENT (which would enable entity substitution)
        // This provides secure XML parsing without external entity processing
        $xml = simplexml_load_string($feedContent, 'SimpleXMLElement', LIBXML_NONET | LIBXML_NOCDATA);
        libxml_clear_errors();
        
        if ($xml === false) {
            throw new Exception('Failed to parse XML');
        }
        
        $status = [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];
        
        // Check if it's an Atom feed
        if (isset($xml->entry)) {
            // If filter provided, find matching entry
            $latestEntry = null;
            if ($filter !== null) {
                foreach ($xml->entry as $entry) {
                    $entryTitle = (string)($entry->title ?? '');
                    if (stripos($entryTitle, $filter) !== false) {
                        $latestEntry = $entry;
                        break;
                    }
                }
                // If no matching entry, return operational
                if ($latestEntry === null) {
                    return $status;
                }
            }
            $latestEntry = $latestEntry ?? $xml->entry[0];
            
            $title = (string)($latestEntry->title ?? '');
            $content = (string)($latestEntry->content ?? '');
            $summary = (string)($latestEntry->summary ?? '');
            
            // Strip CDATA tags if present (e.g., Brevo feed)
            $title = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $title);
            $content = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $content);
            $summary = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $summary);
            
            // Get entry timestamp
            $entryDate = null;
            if (isset($latestEntry->updated)) {
                $entryDate = strtotime((string)$latestEntry->updated);
            } elseif (isset($latestEntry->published)) {
                $entryDate = strtotime((string)$latestEntry->published);
            }
            
            // Check if entry is within 24 hours (86400 seconds)
            $isRecent = ($entryDate && (time() - $entryDate) <= 86400);
            
            // Combine title, content, summary for better matching
            $fullText = $title . ' ' . $content . ' ' . $summary;
            
            // Only show incidents if recent AND active (not resolved/completed)
            // Check for resolved/completed keywords which indicate the incident is over
            $isResolved = preg_match('/\b(resolved|completed|fixed|closed|ended|restored|operational)\b/i', $title);
            
            // If not recent or if resolved, no incident
            if (!$isRecent || $isResolved) {
                return [
                    'indicator' => 'none',
                    'description' => 'All Systems Operational'
                ];
            }
            
            // Check severity of active incident
            if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
                return [
                    'indicator' => 'major',
                    'description' => 'Major Outage'
                ];
            }
            
            // Any other active incident is considered minor
            return [
                'indicator' => 'minor',
                'description' => 'Partially Degraded Service'
            ];
        }
        // Check if it's an RSS feed
        elseif (isset($xml->channel->item)) {
            // If filter provided, find matching item
            $latestItem = null;
            if ($filter !== null) {
                foreach ($xml->channel->item as $item) {
                    $itemTitle = (string)($item->title ?? '');
                    if (stripos($itemTitle, $filter) !== false) {
                        $latestItem = $item;
                        break;
                    }
                }
                // If no matching item, return operational
                if ($latestItem === null) {
                    return $status;
                }
            }
            $latestItem = $latestItem ?? $xml->channel->item[0];
            
            $title = (string)($latestItem->title ?? '');
            $description = (string)($latestItem->description ?? '');
            
            // Get item timestamp
            $itemDate = null;
            if (isset($latestItem->pubDate)) {
                $itemDate = strtotime((string)$latestItem->pubDate);
            } elseif (isset($latestItem->children('http://purl.org/dc/elements/1.1/')->date)) {
                $itemDate = strtotime((string)$latestItem->children('http://purl.org/dc/elements/1.1/')->date);
            }
            
            // Check if item is within 24 hours (86400 seconds)
            $isRecent = ($itemDate && (time() - $itemDate) <= 86400);
            
            // Combine title and description for better matching
            $fullText = $title . ' ' . $description;
            
            // Only show incidents if recent AND active (not resolved/completed)
            // Check for resolved/completed keywords which indicate the incident is over
            $isResolved = preg_match('/\b(resolved|completed|fixed|closed|ended|restored|operational)\b/i', $title);
            
            // If not recent or if resolved, no incident
            if (!$isRecent || $isResolved) {
                return [
                    'indicator' => 'none',
                    'description' => 'All Systems Operational'
                ];
            }
            
            // Check severity of active incident
            if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
                return [
                    'indicator' => 'major',
                    'description' => 'Major Outage'
                ];
            }
            
            // Any other active incident is considered minor
            return [
                'indicator' => 'minor',
                'description' => 'Partially Degraded Service'
            ];
        }
        
        return $status;
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

    /**
     * Unified JSON API parser with configurable structure mapping
     * Handles various JSON API formats with standardized incident detection
     * 
     * @param string $apiUrl The API endpoint URL
     * @param array $config Configuration for parsing this specific API format
     * @return array Status information with indicator and description
     */
    public function parseJsonAPI(string $apiUrl, array $config): array
    {
    try {
        // Fetch API response via cURL with SSL verification
        // codacy:ignore - curl functions required for secure outbound HTTP in standalone API
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $apiUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER => [
                'User-Agent: EngineScript Admin Dashboard'
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $httpCode !== 200) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to parse status'
            ];
        }
        
        // Check if data structure is valid
        if (isset($config['required_field']) && !isset($data[$config['required_field']])) {
            // Required field missing - treat as operational or error based on config
            return isset($config['missing_is_operational']) && $config['missing_is_operational']
                ? ['indicator' => 'none', 'description' => 'All Systems Operational']
                : ['indicator' => 'major', 'description' => 'Unable to fetch status'];
        }
        
        // Handle direct status indicator APIs (like StatusPage.io)
        if (isset($config['type']) && $config['type'] === 'direct_status') {
            $statusPath = explode('.', $config['status_path']);
            $statusData = $data;
            foreach ($statusPath as $key) {
                if (!isset($statusData[$key])) {
                    return ['indicator' => 'major', 'description' => 'Unable to parse status'];
                }
                $statusData = $statusData[$key];
            }
            
            $indicator = $statusData['indicator'] ?? 'none';
            $description = $statusData['description'] ?? 'All Systems Operational';
            
            // Standardize indicator
            if ($indicator === 'none' || $indicator === 'operational') {
                return ['indicator' => 'none', 'description' => 'All Systems Operational'];
            }
            if ($indicator === 'major' || $indicator === 'critical') {
                return ['indicator' => 'major', 'description' => 'Major Outage'];
            }
            return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
        }
        
        // Handle page status APIs (like Wistia)
        if (isset($config['type']) && $config['type'] === 'page_status') {
            $pageStatus = isset($data[$config['page_path']]['status']) 
                ? strtoupper($data[$config['page_path']]['status']) 
                : 'UNKNOWN';
            
            if ($pageStatus === 'OK' || $pageStatus === 'OPERATIONAL') {
                return ['indicator' => 'none', 'description' => 'All Systems Operational'];
            }
            
            // Check for active incidents
            if (isset($data[$config['incidents_path']]) && !empty($data[$config['incidents_path']])) {
                $latestIncident = reset($data[$config['incidents_path']]);
                $title = $latestIncident[$config['title_field']] ?? '';
                
                if (preg_match('/outage|down|major|critical|offline/i', $title)) {
                    return ['indicator' => 'major', 'description' => 'Major Outage'];
                }
                
                // Check severity field if configured
                if (isset($config['severity_field']) && isset($latestIncident[$config['severity_field']])) {
                    $severity = strtoupper($latestIncident[$config['severity_field']]);
                    if (in_array($severity, ['MAJOROUTAGE', 'CRITICAL', 'HIGH'])) {
                        return ['indicator' => 'major', 'description' => 'Major Outage'];
                    }
                }
                
                return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
            }
            
            if ($pageStatus === 'HASISSUES') {
                return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
            }
            
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }
        
        // Handle incident list APIs (Vultr, Postmark, Google Workspace)
        $incidents = $data;
        
        // Navigate to incidents array if path specified
        if (isset($config['incidents_path'])) {
            $path = explode('.', $config['incidents_path']);
            foreach ($path as $key) {
                if (!isset($incidents[$key])) {
                    return ['indicator' => 'none', 'description' => 'All Systems Operational'];
                }
                $incidents = $incidents[$key];
            }
        }
        
        if (empty($incidents)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }
        
        // Filter incidents based on status field
        if (isset($config['filter_field']) && isset($config['filter_value'])) {
            $filteredIncidents = array_filter($incidents, function($incident) use ($config) {
                if (is_array($config['filter_value'])) {
                    foreach ($config['filter_value'] as $field => $value) {
                        if (!isset($incident[$field]) || $incident[$field] !== $value) {
                            return false;
                        }
                    }
                    return true;
                }
                return isset($incident[$config['filter_field']]) && $incident[$config['filter_field']] === $config['filter_value'];
            });
            
            if (empty($filteredIncidents)) {
                return ['indicator' => 'none', 'description' => 'All Systems Operational'];
            }
            
            $incidents = $filteredIncidents;
        }
        
        // Get latest incident
        $latestIncident = reset($incidents);
        
        // Extract title with custom parser if provided
        if (isset($config['title_parser']) && is_callable($config['title_parser'])) {
            $title = $config['title_parser']($latestIncident);
        }
        if (!isset($title) || empty($title)) {
            $title = $latestIncident[$config['title_field']] ?? '';
        }
        
        // Get description field if specified
        $description = '';
        if (isset($config['description_field']) && isset($latestIncident[$config['description_field']])) {
            $description = $latestIncident[$config['description_field']];
        }
        
        if (empty($title)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }
        
        // Check recency if timestamp field configured
        if (isset($config['timestamp_fields'])) {
            $incidentDate = null;
            foreach ($config['timestamp_fields'] as $field) {
                if (isset($latestIncident[$field])) {
                    $incidentDate = strtotime($latestIncident[$field]);
                    break;
                }
            }
            
            if ($incidentDate && (time() - $incidentDate) > 86400) {
                return ['indicator' => 'none', 'description' => 'All Systems Operational'];
            }
        }
        
        // Check if resolved
        $fullText = $title . ' ' . $description;
        if (preg_match('/\b(resolved|completed|fixed|closed|ended|restored|operational)\b/i', $fullText)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }
        
        // Determine severity - check keywords first
        if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
            return ['indicator' => 'major', 'description' => 'Major Outage'];
        }
        
        // Check severity field if configured
        if (isset($config['severity_field']) && isset($latestIncident[$config['severity_field']])) {
            $severity = strtolower($latestIncident[$config['severity_field']]);
            if (in_array($severity, ['high', 'critical', 'major'])) {
                return ['indicator' => 'major', 'description' => 'Major Outage'];
            }
        }
        
        return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

    /**
     * Parse Google Workspace incidents JSON API
     * Custom title parser for Google's unique format
     */
    public function parseGoogleWorkspaceIncidents(string $apiUrl): array
    {
        return $this->parseJsonAPI($apiUrl, [
        'title_field' => 'external_desc',
        'description_field' => 'external_desc',
        'severity_field' => 'severity',
        'timestamp_fields' => ['start_time', 'created_at', 'updated_at', 'time'],
        'missing_is_operational' => true,
        'title_parser' => function($incident) {
            $description = $incident['external_desc'] ?? '';
            
            // Parse title - extract text after **Title:** marker
            if (preg_match('/\*\*Title:?\*\*\s*\n(.+?)(?:\n|$)/s', $description, $matches)) {
                return trim($matches[1]);
            } elseif (preg_match('/\*\*Title:?\*\*\s*(.+?)(?:\n|$)/s', $description, $matches)) {
                return trim($matches[1]);
            }
            
            // No title marker, use first line
            return strtok($description, "\n");
        }
    ]);
}

    /**
     * Parse Wistia summary JSON API
     */
    public function parseWistiaSummary(string $apiUrl): array
    {
        return $this->parseJsonAPI($apiUrl, [
        'type' => 'page_status',
        'page_path' => 'page',
        'incidents_path' => 'activeIncidents',
        'title_field' => 'name',
        'severity_field' => 'impact',
        'required_field' => 'page'
    ]);
}

    /**
     * Parse Vultr alerts JSON API
     */
    public function parseVultrAlerts(string $apiUrl): array
    {
        return $this->parseJsonAPI($apiUrl, [
        'incidents_path' => 'service_alerts',
        'title_field' => 'subject',
        'filter_field' => 'status',
        'filter_value' => 'ongoing',
        'missing_is_operational' => true
    ]);
}

    /**
     * Parse Postmark notices API
     */
    public function parsePostmarkNotices(string $apiUrl): array
    {
        return $this->parseJsonAPI($apiUrl, [
        'incidents_path' => 'notices',
        'title_field' => 'title',
        'filter_field' => 'multiple',
        'filter_value' => ['type' => 'unplanned', 'timeline_state' => 'present'],
        'missing_is_operational' => true
    ]);
}

    /**
     * Parse standard StatusPage.io JSON API
     */
    public function parseStatusPageAPI(string $apiUrl): array
    {
        return $this->parseJsonAPI($apiUrl, [
        'type' => 'direct_status',
        'status_path' => 'status',
        'required_field' => 'status'
    ]);
}

    /**
     * Handle RSS/Atom feed status requests
     * 
     * @param string $feedType The feed type identifier (must be whitelisted)
     * @param string|null $filter Optional service name filter for multi-service feeds
     * @return void Outputs JSON response via ApiResponse
     */
    public function handleStatusFeed(string $feedType, ?string $filter = null): void
    {
        try {
            // Whitelist validation for feed types to prevent injection
            $allowedFeedTypes = [
                'vultr', 'googleworkspace', 'wistia', 'postmark', 'automattic',
                'stripe', 'letsencrypt', 'flare', 'slack', 'gitlab',
                'square', 'recurly', 'googleads', 'googlesearch', 'microsoftads',
                'paypal', 'googlecloud', 'oracle', 'ovh', 'brevo', 'sendgrid',
                'anthropic', 'spotify', 'metafb', 'metamarketingapi', 'metafbs', 'metalogin',
                'trello', 'pipedream', 'codacy', 'openai',
                'sparkpost', 'zoho', 'mailjet', 'mailersend', 'resend', 'smtp2go', 'sendlayer'
            ];

            if (!in_array($feedType, $allowedFeedTypes, true)) {
                ApiResponse::badRequest('Invalid feed type');
                return;
            }

            // Handle special JSON API feeds
            if ($feedType === 'vultr') {
                $status = $this->parseVultrAlerts('https://status.vultr.com/alerts.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'postmark') {
                $status = $this->parsePostmarkNotices('https://status.postmarkapp.com/api/v1/notices?filter[timeline_state_eq]=present&filter[type_eq]=unplanned');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'googleworkspace') {
                $status = $this->parseGoogleWorkspaceIncidents('https://www.google.com/appsstatus/dashboard/incidents.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'wistia') {
                $status = $this->parseWistiaSummary('https://status.wistia.com/summary.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'sendgrid') {
                $status = $this->parseStatusPageAPI('https://status.sendgrid.com/api/v2/status.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'spotify') {
                $status = $this->parseStatusPageAPI('https://spotify.statuspage.io/api/v2/status.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'trello') {
                $status = $this->parseStatusPageAPI('https://trello.status.atlassian.com/api/v2/status.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            if ($feedType === 'pipedream') {
                $status = $this->parseStatusPageAPI('https://status.pipedream.com/api/v2/status.json');
                ApiResponse::success(['status' => $status]);
                return;
            }

            // Whitelist allowed RSS/Atom feeds for security
            $allowedFeeds = [
                'stripe' => 'https://www.stripestatus.com/history.atom',
                'letsencrypt' => 'https://letsencrypt.status.io/pages/55957a99e800baa4470002da/rss',
                'flare' => 'https://status.flare.io/history/rss',
                'slack' => 'https://slack-status.com/feed/atom',
                'gitlab' => 'https://status.gitlab.com/pages/5b36dc6502d06804c08349f7/rss',
                'square' => 'https://www.issquareup.com/united-states/feed.atom',
                'recurly' => 'https://status.recurly.com/statuspage/recurly/subscribe/rss',
                'googleads' => 'https://ads.google.com/status/publisher/en/feed.atom',
                'googlesearch' => 'https://status.search.google.com/en/feed.atom',
                'microsoftads' => 'https://status.ads.microsoft.com/feed?cat=27',
                'paypal' => 'https://www.paypal-status.com/feed/atom',
                'googlecloud' => 'https://status.cloud.google.com/en/feed.atom',
                'oracle' => 'https://ocistatus.oraclecloud.com/api/v2/incident-summary.rss',
                'ovh' => 'https://public-cloud.status-ovhcloud.com/history.atom',
                'brevo' => 'https://status.brevo.com/feed.atom',
                'automattic' => 'https://automatticstatus.com/rss',
                'anthropic' => 'https://status.claude.com/history.atom',
                'metafb' => 'https://metastatus.com/outage-events-feed-fb-ig-shops.rss',
                'metamarketingapi' => 'https://metastatus.com/outage-events-feed-marketing-api.rss',
                'metafbs' => 'https://metastatus.com/outage-events-feed-fbs.rss',
                'metalogin' => 'https://metastatus.com/outage-events-feed-facebook-login.rss',
                'codacy' => 'https://status.codacy.com/history.rss',
                'openai' => 'https://status.openai.com/feed.atom',
                'sparkpost' => 'https://status.sparkpost.com/history.atom',
                'zoho' => 'https://status.zoho.com/rss',
                'mailjet' => 'https://status.mailjet.com/history.rss',
                'mailersend' => 'https://status.mailersend.com/history.rss',
                'resend' => 'https://resend-status.com/feed.rss',
                'smtp2go' => 'https://smtp2gostatus.com/history.atom',
                'sendlayer' => 'https://status.sendlayer.com/history/rss'
            ];

            if (!isset($allowedFeeds[$feedType])) {
                ApiResponse::badRequest('Invalid feed type');
                return;
            }

            $feedUrl = $allowedFeeds[$feedType];

            // Parse feed and return status
            $status = $this->parseStatusFeed($feedUrl, $filter);

            ApiResponse::success(['status' => $status]);
            return;

        } catch (Exception $e) {
            error_log('Status feed error: ' . $e->getMessage());
            ApiResponse::serverError('Unable to fetch status feed');
            return;
        }
    }

    /**
     * Get external services configuration
     * Returns all available services (preferences stored client-side)
     * 
     * @return array<string, bool> Map of service identifiers to enabled status
     */
    public static function getServicesConfig(): array
    {
        return [
        // Hosting & Infrastructure
        'aws' => true,
        'cloudflare' => true,
        'cloudways' => true,
        'digitalocean' => true,
        'googlecloud' => true,
        'hostinger' => true,
        'jetpackapi' => true,
        'kinsta' => true,
        'linode' => true,
        'oracle' => true,
        'ovh' => true,
        'scaleway' => true,
        'upcloud' => true,
        'vercel' => true,
        'vultr' => true,
        'godaddy' => true,
        'wordpressapi' => true,
        'wpcloudapi' => true,

        // Developer Tools
        'codacy' => true,
        'github' => true,
        'gitlab' => true,
        'notion' => true,
        'pipedream' => true,
        'postmark' => true,
        'trello' => true,
        'twilio' => true,
        
        // E-Commerce & Payments
        'coinbase' => true,
        'intuit' => true,
        'metafb' => true,
        'paypal' => true,
        'recurly' => true,
        'shopify' => true,
        'square' => true,
        'stripe' => true,
        'woocommercepay' => true,
        
        // Email Services
        'brevo' => true,
        'mailersend' => true,
        'mailgun' => true,
        'mailjet' => true,
        'mailpoet' => true,
        'postmark' => true,
        'resend' => true,
        'sendgrid' => true,
        'sendlayer' => true,
        'smtp2go' => true,
        'sparkpost' => true,
        'zoho' => true,
        
        // Communication
        'discord' => true,
        'slack' => true,
        'zoom' => true,
        
        // Media & Content
        'dropbox' => true,
        'reddit' => true,
        'spotify' => true,
        'udemy' => true,
        'vimeo' => true,
        'wistia' => true,
        
        // AI & Machine Learning
        'anthropic' => true,
        'openai' => true,
        
        // Advertising
        'googleads' => true,
        'googlesearch' => true,
        'googleworkspace' => true,
        'metafb' => true,
        'metafbs' => true,
        'metalogin' => true,
        'metamarketingapi' => true,
        'microsoftads' => true,
        
        // Security
        'letsencrypt' => true,
        'flare' => true
    ];
    }
}
