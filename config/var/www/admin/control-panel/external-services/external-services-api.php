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

/**
 * Sanitize text from external feeds to prevent injection attacks
 * @param string $text Raw text from feed
 * @return string Sanitized text safe for output
 */
function sanitizeFeedText($text) {
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
function parseStatusFeed($feedUrl, $filter = null) {
    try {
        // Set up context with timeout and user agent
        // @codacy suppress [The use of function stream_context_create() is discouraged] Required for HTTP timeout configuration on outbound requests
        $context = stream_context_create([
            'http' => [
                'timeout' => 45,
                'user_agent' => 'EngineScript-StatusMonitor/1.0',
                'ignore_errors' => true
            ]
        ]);
        
        // Fetch feed content
        set_error_handler(function($severity, $message, $file, $line) {
            // @codacy suppress [XSS] Internal error handler - exception message never output to browser
            throw new ErrorException($message, 0, $severity, $file, $line);
        });
        
        try {
            // @codacy suppress [The use of function file_get_contents() is discouraged] Used for outbound HTTP requests with timeout protection - not file system access
            $feedContent = file_get_contents($feedUrl, false, $context);
        } catch (Exception $e) {
            $feedContent = false;
        } finally {
            restore_error_handler();
        }
        
        if ($feedContent === false) {
            throw new Exception('Failed to fetch feed');
        }
        
        // Suppress XML errors and parse securely
        libxml_use_internal_errors(true);
        // Disable external entity processing to prevent XXE attacks
        libxml_disable_entity_loader(true);
        // Parse XML without entity substitution (secure by default)
        // Do not use LIBXML_NOENT as it enables external entity substitution
        $xml = simplexml_load_string($feedContent, 'SimpleXMLElement');
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
                    $entryTitle = isset($entry->title) ? (string)$entry->title : '';
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
            
            $title = isset($latestEntry->title) ? (string)$latestEntry->title : '';
            $content = isset($latestEntry->content) ? (string)$latestEntry->content : '';
            $summary = isset($latestEntry->summary) ? (string)$latestEntry->summary : '';
            
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
            
            if (!$isRecent || $isResolved) {
                // No active incident
                $status['indicator'] = 'none';
                $status['description'] = 'All Systems Operational';
            } else {
                // Active incident detected - check severity
                if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
                    $status['indicator'] = 'major';
                    $status['description'] = 'Major Outage';
                } else {
                    // Any other active incident is considered minor
                    $status['indicator'] = 'minor';
                    $status['description'] = 'Partially Degraded Service';
                }
            }
        }
        // Check if it's an RSS feed
        elseif (isset($xml->channel->item)) {
            // If filter provided, find matching item
            $latestItem = null;
            if ($filter !== null) {
                foreach ($xml->channel->item as $item) {
                    $itemTitle = isset($item->title) ? (string)$item->title : '';
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
            
            $title = isset($latestItem->title) ? (string)$latestItem->title : '';
            $description = isset($latestItem->description) ? (string)$latestItem->description : '';
            
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
            
            if (!$isRecent || $isResolved) {
                // No active incident
                $status['indicator'] = 'none';
                $status['description'] = 'All Systems Operational';
            } else {
                // Active incident detected - check severity
                if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
                    $status['indicator'] = 'major';
                    $status['description'] = 'Major Outage';
                } else {
                    // Any other active incident is considered minor
                    $status['indicator'] = 'minor';
                    $status['description'] = 'Partially Degraded Service';
                }
            }
        }
        
        // Truncate long descriptions
        if (strlen($status['description']) > 200) {
            $status['description'] = substr($status['description'], 0, 197) . '...';
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
 * Parse Google Workspace incidents JSON API
 */
function parseGoogleWorkspaceIncidents($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        // @codacy suppress [The use of function file_get_contents() is discouraged] Outbound HTTP request to external API with timeout
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || empty($data)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the first incident (most recent)
        $latestIncident = reset($data);
        
        // Extract title from external_desc (format: **Title:**\nActual title text)
        $description = isset($latestIncident['external_desc']) ? $latestIncident['external_desc'] : '';
        
        // Parse title - extract text after **Title:** marker
        $title = '';
        if (preg_match('/\*\*Title:?\*\*\s*\n(.+?)(?:\n|$)/s', $description, $matches)) {
            $title = trim($matches[1]);
        } elseif (preg_match('/\*\*Title:?\*\*\s*(.+?)(?:\n|$)/s', $description, $matches)) {
            // Fallback: title on same line
            $title = trim($matches[1]);
        }
        if (empty($title)) {
            // No title marker, use first line
            $title = strtok($description, "\n");
        }
        
        if (empty($title)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Determine recency (if timestamp available) and severity
        $incidentDate = null;
        if (isset($latestIncident['start_time'])) {
            $incidentDate = strtotime($latestIncident['start_time']);
        } elseif (isset($latestIncident['created_at'])) {
            $incidentDate = strtotime($latestIncident['created_at']);
        } elseif (isset($latestIncident['updated_at'])) {
            $incidentDate = strtotime($latestIncident['updated_at']);
        } elseif (isset($latestIncident['time'])) {
            $incidentDate = strtotime($latestIncident['time']);
        }

        // If incident has a timestamp and it's older than 24 hours, treat as operational
        if ($incidentDate && (time() - $incidentDate) > 86400) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Check if incident is resolved
        $fullText = $title . ' ' . $description;
        $isResolved = preg_match('/\b(resolved|completed|fixed|closed|ended|restored|operational)\b/i', $fullText);
        
        if ($isResolved) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }

        // Determine severity - check for major keywords first
        if (preg_match('/\b(major\s+(downtime|outage)|major\s+incident)\b/i', $fullText)) {
            return [
                'indicator' => 'major',
                'description' => 'Major Outage'
            ];
        } elseif (isset($latestIncident['severity'])) {
            $severity = strtolower($latestIncident['severity']);
            if (in_array($severity, ['high', 'critical'])) {
                return [
                    'indicator' => 'major',
                    'description' => 'Major Outage'
                ];
            }
        }
        
        return [
            'indicator' => 'minor',
            'description' => 'Partially Degraded Service'
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Wistia summary JSON API
 */
function parseWistiaSummary($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['page'])) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        // Check page status
        $pageStatus = isset($data['page']['status']) ? strtoupper($data['page']['status']) : 'UNKNOWN';
        
        // If no issues, return operational
        if ($pageStatus === 'OK' || $pageStatus === 'OPERATIONAL') {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Check for active incidents
        if (isset($data['activeIncidents']) && !empty($data['activeIncidents'])) {
            $latestIncident = reset($data['activeIncidents']);
            $name = isset($latestIncident['name']) ? $latestIncident['name'] : 'Service Issue';
            
            // Check for major outage keywords
            if (preg_match('/\b(major\s+(downtime|outage)|major\s+incident)\b/i', $name)) {
                return [
                    'indicator' => 'major',
                    'description' => 'Major Outage'
                ];
            }
            
            // Determine severity from impact
            if (isset($latestIncident['impact'])) {
                $impact = strtoupper($latestIncident['impact']);
                if (in_array($impact, ['MAJOROUTAGE', 'CRITICAL'])) {
                    return [
                        'indicator' => 'major',
                        'description' => 'Major Outage'
                    ];
                }
            }
            
            return [
                'indicator' => 'minor',
                'description' => 'Partially Degraded Service'
            ];
        }
        
        // Has issues but no active incidents listed
        if ($pageStatus === 'HASISSUES') {
            return [
                'indicator' => 'minor',
                'description' => 'Partially Degraded Service'
            ];
        }
        
        return [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Vultr alerts JSON API
 */
function parseVultrAlerts($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['service_alerts'])) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Check for ongoing alerts only
        $ongoingAlerts = array_filter($data['service_alerts'], function($alert) {
            return isset($alert['status']) && $alert['status'] === 'ongoing';
        });
        
        if (empty($ongoingAlerts)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the most recent ongoing alert
        $latestAlert = reset($ongoingAlerts);
        $subject = isset($latestAlert['subject']) ? $latestAlert['subject'] : 'Service Alert';
        
        // Check for major outage keywords
        if (preg_match('/\b(major\s+(downtime|outage)|major\s+incident)\b/i', $subject)) {
            return [
                'indicator' => 'major',
                'description' => 'Major Outage'
            ];
        }
        
        // Check for other severe keywords
        if (preg_match('/outage|down|critical|offline/i', $subject)) {
            return [
                'indicator' => 'major',
                'description' => 'Major Outage'
            ];
        }
        
        return [
            'indicator' => 'minor',
            'description' => 'Partially Degraded Service'
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Postmark notices API
 */
function parsePostmarkNotices($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['notices'])) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Filter for current unplanned notices
        $currentUnplanned = array_filter($data['notices'], function($notice) {
            $isUnplanned = isset($notice['type']) && $notice['type'] === 'unplanned';
            $isPresent = isset($notice['timeline_state']) && $notice['timeline_state'] === 'present';
            return $isUnplanned && $isPresent;
        });
        
        if (empty($currentUnplanned)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the most recent current unplanned notice
        $latestNotice = reset($currentUnplanned);
        $title = isset($latestNotice['title']) ? $latestNotice['title'] : 'Unplanned Incident';
        
        // Check for major outage keywords
        if (preg_match('/\b(major\s+(downtime|outage)|major\s+incident)\b/i', $title)) {
            return [
                'indicator' => 'major',
                'description' => 'Major Outage'
            ];
        }
        
        // Check for other severe keywords
        if (preg_match('/outage|down|critical|offline/i', $title)) {
            return [
                'indicator' => 'major',
                'description' => 'Major Outage'
            ];
        }
        
        return [
            'indicator' => 'minor',
            'description' => 'Partially Degraded Service'
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse standard StatusPage.io JSON API
 */
function parseStatusPageAPI($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['status'])) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to parse status'
            ];
        }
        
        $statusData = $data['status'];
        $indicator = isset($statusData['indicator']) ? $statusData['indicator'] : 'none';
        $description = isset($statusData['description']) ? $statusData['description'] : 'All Systems Operational';
        
        // Standardize status messages
        if ($indicator === 'none' || $indicator === 'operational') {
            $standardDescription = 'All Systems Operational';
        } elseif ($indicator === 'major' || $indicator === 'critical') {
            $standardDescription = 'Major Outage';
        } else {
            // Check description for major keywords
            if (preg_match('/\b(major\s+(downtime|outage)|major\s+incident)\b/i', $description)) {
                $indicator = 'major';
                $standardDescription = 'Major Outage';
            } else {
                $indicator = 'minor';
                $standardDescription = 'Partially Degraded Service';
            }
        }
        
        return [
            'indicator' => $indicator,
            'description' => $standardDescription
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Handle RSS/Atom feed status requests
 */
function handleStatusFeed() {
    try {
        // Validate feed parameter
        // @codacy [Direct use of $_GET Superglobal detected] Input validated against strict whitelist below
        if (!isset($_GET['feed']) || empty($_GET['feed'])) {
            http_response_code(400);
            header('Content-Type: application/json');
            // @codacy suppress [Use of echo language construct is discouraged] API endpoint must output JSON response
            echo json_encode(['error' => 'Missing feed parameter']);
            // @codacy suppress [Use of exit language construct is discouraged] API endpoint must terminate after response
            exit;
        }
        
        // @codacy [Direct use of $_GET Superglobal detected] Input validated against whitelist of allowed feed types
        $feedType = $_GET['feed'];
        
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
            http_response_code(400);
            header('Content-Type: application/json');
            // @codacy suppress [Use of echo language construct is discouraged] API endpoint must output JSON response
            echo json_encode(['error' => 'Invalid feed type']);
            // @codacy suppress [Use of exit language construct is discouraged] API endpoint must terminate after response
            exit;
        }
        
        // Handle special JSON API feeds
        if ($feedType === 'vultr') {
            $status = parseVultrAlerts('https://status.vultr.com/alerts.json');
            header('Content-Type: application/json');
            // @codacy suppress [Use of echo language construct is discouraged] API endpoint JSON response
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'postmark') {
            $status = parsePostmarkNotices('https://status.postmarkapp.com/api/v1/notices?filter[timeline_state_eq]=present&filter[type_eq]=unplanned');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'googleworkspace') {
            $status = parseGoogleWorkspaceIncidents('https://www.google.com/appsstatus/dashboard/incidents.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'wistia') {
            $status = parseWistiaSummary('https://status.wistia.com/summary.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'sendgrid') {
            $status = parseStatusPageAPI('https://status.sendgrid.com/api/v2/status.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'spotify') {
            $status = parseStatusPageAPI('https://spotify.statuspage.io/api/v2/status.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'trello') {
            $status = parseStatusPageAPI('https://trello.status.atlassian.com/api/v2/status.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
        }
        
        if ($feedType === 'pipedream') {
            $status = parseStatusPageAPI('https://status.pipedream.com/api/v2/status.json');
            header('Content-Type: application/json');
            echo json_encode(['status' => $status]);
            exit;
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
            http_response_code(400);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'Invalid feed type']);
            exit;
        }
        
        $feedUrl = $allowedFeeds[$feedType];
        
        // Get optional filter parameter for feeds like automattic
        // @codacy [Direct use of $_GET Superglobal detected] Input sanitized below with regex whitelist and length limit
        // @codacy suppress [not unslashed before sanitization] Not WordPress - wp_unslash() doesn't exist in standalone PHP
        $filter = isset($_GET['filter']) ? $_GET['filter'] : null;
        
        // Sanitize filter parameter to prevent injection
        if ($filter !== null) {
            // Allow alphanumeric, spaces, hyphens, periods, parentheses for service names
            $filter = preg_replace('/[^a-zA-Z0-9 \-\.\(\)]/', '', $filter);
            // Limit length to reasonable service name size
            $filter = substr($filter, 0, 100);
            if (empty($filter)) {
                $filter = null;
            }
        }
        
        // Parse feed and return status
        $status = parseStatusFeed($feedUrl, $filter);
        
        header('Content-Type: application/json');
        echo json_encode(['status' => $status]);
        exit;
        
    } catch (Exception $e) {
        http_response_code(500);
        header('Content-Type: application/json');
        error_log('Status feed error: ' . $e->getMessage());
        echo json_encode(['error' => 'Unable to fetch status feed']);
        exit;
    }
}

/**
 * Get external services configuration
 * Returns all available services (preferences stored client-side)
 */
function getExternalServicesConfig() {
    // All services available - user preferences stored client-side in cookies
    $config = [
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
    
    return $config;
}

/**
 * Handle external services config request
 * Returns list of all available services
 * Note: User preferences are stored client-side in cookies, not on server
 */
function handleExternalServicesConfig() {
    try {
        $config = getExternalServicesConfig();
        
        // Return all available services (preferences stored client-side in cookies)
        header('Content-Type: application/json');
        // @codacy suppress [Use of echo language construct is discouraged] API endpoint JSON response
        echo json_encode($config);
        exit;
    } catch (Exception $e) {
        http_response_code(500);
        header('Content-Type: application/json');
        error_log('External services config error: ' . $e->getMessage());
        // @codacy suppress [Use of echo language construct is discouraged] API endpoint JSON error response
        echo json_encode(['error' => 'Unable to retrieve external services config']);
        exit;
    }
}
