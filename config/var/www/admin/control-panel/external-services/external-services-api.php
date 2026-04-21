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
     * Dedicated JSON API parser dependency.
     *
     * @var ExternalServicesJsonApiParser
     */
    private ExternalServicesJsonApiParser $jsonApiParser;

    /**
     * Service catalog dependency.
     *
     * @var ExternalServicesServiceCatalog
     */
    private ExternalServicesServiceCatalog $serviceCatalog;

    /**
     * @param ExternalServicesJsonApiParser|null $jsonApiParser Optional JSON parser dependency
     * @param ExternalServicesServiceCatalog|null $serviceCatalog Optional service catalog dependency
     */
    public function __construct(
        ?ExternalServicesJsonApiParser $jsonApiParser = null,
        ?ExternalServicesServiceCatalog $serviceCatalog = null
    ) {
        $this->jsonApiParser = $jsonApiParser ?? new ExternalServicesJsonApiParser();
        $this->serviceCatalog = $serviceCatalog ?? new ExternalServicesServiceCatalog();
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

            // Check if it's an Atom feed
            if (isset($xml->entry)) {
                return $this->parseAtomFeedEntries($xml, $filter);
            }

            // Check if it's an RSS feed
            if (isset($xml->channel->item)) {
                return $this->parseRssFeedItems($xml, $filter);
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
     * Parse Atom feed entries for status information
     * @param SimpleXMLElement $xml The parsed Atom feed
     * @param string|null $filter Optional filter to match specific service name
     * @return array Status information with indicator and description
     */
    private function parseAtomFeedEntries(SimpleXMLElement $xml, ?string $filter): array
    {
        $status = [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];

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
        if ($latestEntry === null) {
            if (!isset($xml->entry[0])) {
                return $status;
            }
            $latestEntry = $xml->entry[0];
        }

        $title = (string)($latestEntry->title ?? '');
        $content = (string)($latestEntry->content ?? '');
        $summary = (string)($latestEntry->summary ?? '');

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

    /**
     * Parse RSS feed items for status information
     * @param SimpleXMLElement $xml The parsed RSS feed
     * @param string|null $filter Optional filter to match specific service name
     * @return array Status information with indicator and description
     */
    private function parseRssFeedItems(SimpleXMLElement $xml, ?string $filter): array
    {
        $status = [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];

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
        if ($latestItem === null) {
            if (!isset($xml->channel->item[0])) {
                return $status;
            }
            $latestItem = $xml->channel->item[0];
        }

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
        return $this->jsonApiParser->parse($apiUrl, $config);
    }

    /**
     * Get JSON API handler configurations keyed by feed type
     *
     * Each entry maps a feed type to its URL and parseJsonAPI config array.
     * Consolidates all JSON API handler definitions in one place.
     *
     * @return array<string, array{url: string, config: array}>
     */
    private function getJsonApiConfigs(): array
    {
        return [
            'vultr' => [
                'url' => 'https://status.vultr.com/alerts.json',
                'config' => [
                    'incidents_path' => 'service_alerts',
                    'title_field' => 'subject',
                    'filter_field' => 'status',
                    'filter_value' => 'ongoing',
                    'missing_is_operational' => true
                ]
            ],
            'postmark' => [
                'url' => 'https://status.postmarkapp.com/api/v1/notices?filter[timeline_state_eq]=present&filter[type_eq]=unplanned',
                'config' => [
                    'incidents_path' => 'notices',
                    'title_field' => 'title',
                    'filter_field' => 'multiple',
                    'filter_value' => ['type' => 'unplanned', 'timeline_state' => 'present'],
                    'missing_is_operational' => true
                ]
            ],
            'googleworkspace' => [
                'url' => 'https://www.google.com/appsstatus/dashboard/incidents.json',
                'config' => [
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
                ]
            ],
            'wistia' => [
                'url' => 'https://status.wistia.com/summary.json',
                'config' => [
                    'type' => 'page_status',
                    'page_path' => 'page',
                    'incidents_path' => 'activeIncidents',
                    'title_field' => 'name',
                    'severity_field' => 'impact',
                    'required_field' => 'page'
                ]
            ],
            'sendgrid' => [
                'url' => 'https://status.sendgrid.com/api/v2/status.json',
                'config' => ['type' => 'direct_status', 'status_path' => 'status', 'required_field' => 'status']
            ],
            'spotify' => [
                'url' => 'https://spotify.statuspage.io/api/v2/status.json',
                'config' => ['type' => 'direct_status', 'status_path' => 'status', 'required_field' => 'status']
            ],
            'trello' => [
                'url' => 'https://trello.status.atlassian.com/api/v2/status.json',
                'config' => ['type' => 'direct_status', 'status_path' => 'status', 'required_field' => 'status']
            ],
            'pipedream' => [
                'url' => 'https://status.pipedream.com/api/v2/status.json',
                'config' => ['type' => 'direct_status', 'status_path' => 'status', 'required_field' => 'status']
            ],
        ];
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
            // Load JSON API feeds via config map
            $jsonApiConfigs = $this->getJsonApiConfigs();

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

            // Consolidated whitelist validation from actual configured handlers
            $allowedFeedTypes = array_unique(array_merge(
                array_keys($jsonApiConfigs),
                array_keys($allowedFeeds)
            ));

            if (!in_array($feedType, $allowedFeedTypes, true)) {
                ApiResponse::badRequest('Invalid feed type');
                return;
            }

            // Handle JSON API feeds via config map
            if (isset($jsonApiConfigs[$feedType])) {
                $apiConfig = $jsonApiConfigs[$feedType];
                $status = $this->parseJsonAPI($apiConfig['url'], $apiConfig['config']);
                ApiResponse::success(['status' => $status]);
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
    public function getServicesConfig(): array
    {
        return $this->serviceCatalog->getServicesConfig();
    }
}

/**
 * Dedicated JSON API parser for external service status endpoints.
 *
 * Splits JSON parsing complexity out of ExternalServicesFeedParser
 * to keep that class focused and easier to maintain.
 */
class ExternalServicesJsonApiParser
{
    /**
     * @var ExternalServicesJsonApiResponseFetcher
     */
    private ExternalServicesJsonApiResponseFetcher $responseFetcher;

    /**
     * @var ExternalServicesJsonApiResultDispatcher
     */
    private ExternalServicesJsonApiResultDispatcher $resultDispatcher;

    /**
     * @param ExternalServicesJsonApiResponseFetcher|null $responseFetcher Optional response fetcher dependency
     * @param ExternalServicesJsonApiResultDispatcher|null $resultDispatcher Optional result dispatcher dependency
     */
    public function __construct(
        ?ExternalServicesJsonApiResponseFetcher $responseFetcher = null,
        ?ExternalServicesJsonApiResultDispatcher $resultDispatcher = null
    ) {
        $this->responseFetcher = $responseFetcher ?? new ExternalServicesJsonApiResponseFetcher();
        $this->resultDispatcher = $resultDispatcher ?? new ExternalServicesJsonApiResultDispatcher();
    }

    /**
     * Parse JSON API status payloads with feed-specific configuration.
     *
     * @param string $apiUrl API endpoint URL
     * @param array $config Parser configuration
     * @return array Status information with indicator and description
     */
    public function parse(string $apiUrl, array $config): array
    {
        try {
            $fetchResult = $this->responseFetcher->fetch($apiUrl);

            if ($fetchResult['error'] !== null) {
                return $fetchResult['error'];
            }

            $data = $fetchResult['data'];

            if (!$this->hasRequiredField($data, $config)) {
                return $this->getMissingFieldStatus($config);
            }

            return $this->resultDispatcher->dispatch($data, $config);
        } catch (Exception $e) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
    }

    /**
     * Validate required top-level JSON field when configured.
     *
     * @param array $data Parsed JSON payload
     * @param array $config Parser configuration
     * @return bool True when payload has required shape
     */
    private function hasRequiredField(array $data, array $config): bool
    {
        if (!isset($config['required_field'])) {
            return true;
        }

        return isset($data[$config['required_field']]);
    }

    /**
     * Build status result when required field is missing.
     *
     * @param array $config Parser configuration
     * @return array Status information
     */
    private function getMissingFieldStatus(array $config): array
    {
        if (!empty($config['missing_is_operational'])) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        return ['indicator' => 'major', 'description' => 'Unable to fetch status'];
    }

}

/**
 * Fetches raw JSON payloads from external APIs.
 */
class ExternalServicesJsonApiResponseFetcher
{
    /**
     * @param string $apiUrl API endpoint URL
     * @return array{data: array, error: ?array}
     */
    public function fetch(string $apiUrl): array
    {
        // codacy:ignore - curl functions required for secure outbound HTTP in standalone API
        $curl = curl_init();
        curl_setopt_array($curl, [
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

        $response = curl_exec($curl);
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);

        if ($response === false || $httpCode !== 200) {
            return [
                'data' => [],
                'error' => ['indicator' => 'major', 'description' => 'Unable to fetch status']
            ];
        }

        $data = json_decode($response, true);

        if (!is_array($data)) {
            return [
                'data' => [],
                'error' => ['indicator' => 'major', 'description' => 'Unable to parse status']
            ];
        }

        return ['data' => $data, 'error' => null];
    }
}

/**
 * Dispatches parsed JSON payloads to feed-type-specific interpreters.
 */
class ExternalServicesJsonApiResultDispatcher
{
    /**
     * @var ExternalServicesJsonIncidentEvaluator
     */
    private ExternalServicesJsonIncidentEvaluator $incidentEvaluator;

    /**
     * @param ExternalServicesJsonIncidentEvaluator|null $incidentEvaluator Optional incident evaluator dependency
     */
    public function __construct(?ExternalServicesJsonIncidentEvaluator $incidentEvaluator = null)
    {
        $this->incidentEvaluator = $incidentEvaluator ?? new ExternalServicesJsonIncidentEvaluator();
    }

    /**
     * @param array $data Parsed API payload
     * @param array $config Parser configuration
     * @return array Status information with indicator and description
     */
    public function dispatch(array $data, array $config): array
    {
        $type = $config['type'] ?? 'incident_list';

        if ($type === 'direct_status') {
            return $this->parseDirectStatusResult($data, $config);
        }

        if ($type === 'page_status') {
            return $this->parsePageStatusResult($data, $config);
        }

        return $this->incidentEvaluator->evaluate($data, $config);
    }

    /**
     * @param array $data Parsed API payload
     * @param array $config Parser configuration
     * @return array Status information with indicator and description
     */
    private function parseDirectStatusResult(array $data, array $config): array
    {
        $statusPath = isset($config['status_path']) ? (string)$config['status_path'] : '';
        $statusData = $this->resolvePathValue($data, $statusPath);

        if (!is_array($statusData)) {
            return ['indicator' => 'major', 'description' => 'Unable to parse status'];
        }

        $indicator = $statusData['indicator'] ?? 'none';

        if ($indicator === 'none' || $indicator === 'operational') {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        if ($indicator === 'major' || $indicator === 'critical') {
            return ['indicator' => 'major', 'description' => 'Major Outage'];
        }

        return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
    }

    /**
     * @param array $data Parsed API payload
     * @param array $config Parser configuration
     * @return array Status information with indicator and description
     */
    private function parsePageStatusResult(array $data, array $config): array
    {
        $pageStatus = $this->extractPageStatus($data, $config);

        if ($pageStatus === 'OK' || $pageStatus === 'OPERATIONAL') {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        $latestIncident = $this->extractLatestIncident($data, $config);
        if ($latestIncident !== null) {
            return $this->evaluateIncidentSeverity($latestIncident, $config);
        }

        if ($pageStatus === 'HASISSUES') {
            return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
        }

        return ['indicator' => 'none', 'description' => 'All Systems Operational'];
    }

    private function extractPageStatus(array $data, array $config): string
    {
        $pagePath = isset($config['page_path']) ? (string)$config['page_path'] : '';
        $pageData = $this->resolvePathValue($data, $pagePath);
        
        return (is_array($pageData) && isset($pageData['status']))
            ? strtoupper((string)$pageData['status'])
            : 'UNKNOWN';
    }

    private function extractLatestIncident(array $data, array $config): ?array
    {
        $incidentsPath = isset($config['incidents_path']) ? (string)$config['incidents_path'] : '';
        $incidents = $this->resolvePathValue($data, $incidentsPath);

        if (is_array($incidents) && !empty($incidents)) {
            $incident = reset($incidents);
            return is_array($incident) ? $incident : null;
        }
        
        return null;
    }

    private function evaluateIncidentSeverity(array $incident, array $config): array
    {
        $titleField = isset($config['title_field']) ? (string)$config['title_field'] : '';
        $title = ($titleField !== '' && isset($incident[$titleField])) ? (string)$incident[$titleField] : '';

        if (preg_match('/outage|down|major|critical|offline/i', $title)) {
            return ['indicator' => 'major', 'description' => 'Major Outage'];
        }

        $severityField = isset($config['severity_field']) ? (string)$config['severity_field'] : '';
        if ($severityField !== '' && isset($incident[$severityField])) {
            $severity = strtoupper((string)$incident[$severityField]);
            if (in_array($severity, ['MAJOROUTAGE', 'CRITICAL', 'HIGH'], true)) {
                return ['indicator' => 'major', 'description' => 'Major Outage'];
            }
        }

        return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
    }

    /**
     * @param array $data Parsed API payload
     * @param string $path Dotted path expression
     * @return mixed
     */
    private function resolvePathValue(array $data, string $path)
    {
        if ($path === '') {
            return $data;
        }

        $resolved = $data;
        foreach (explode('.', $path) as $segment) {
            if (!is_array($resolved) || !isset($resolved[$segment])) {
                return null;
            }
            $resolved = $resolved[$segment];
        }

        return $resolved;
    }
}

/**
 * Evaluates incident-based payloads and produces normalized status output.
 */
class ExternalServicesJsonIncidentEvaluator
{
    /**
     * @var ExternalServicesJsonIncidentsResolver
     */
    private ExternalServicesJsonIncidentsResolver $incidentResolver;

    /**
     * @var ExternalServicesJsonIncidentClassifier
     */
    private ExternalServicesJsonIncidentClassifier $incidentClassifier;

    /**
     * @param ExternalServicesJsonIncidentsResolver|null $incidentResolver Optional incident resolver dependency
     * @param ExternalServicesJsonIncidentClassifier|null $incidentClassifier Optional incident classifier dependency
     */
    public function __construct(
        ?ExternalServicesJsonIncidentsResolver $incidentResolver = null,
        ?ExternalServicesJsonIncidentClassifier $incidentClassifier = null
    ) {
        $this->incidentResolver = $incidentResolver ?? new ExternalServicesJsonIncidentsResolver();
        $this->incidentClassifier = $incidentClassifier ?? new ExternalServicesJsonIncidentClassifier();
    }

    /**
     * @param array $data Parsed API payload
     * @param array $config Parser configuration
     * @return array Status information with indicator and description
     */
    public function evaluate(array $data, array $config): array
    {
        $incidents = $this->incidentResolver->getConfiguredIncidents($data, $config);

        if (empty($incidents)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        $latestIncident = reset($incidents);
        if (!is_array($latestIncident)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        $title = $this->incidentClassifier->extractIncidentTitle($latestIncident, $config);
        if ($title === '') {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        if (!$this->incidentClassifier->isIncidentRecent($latestIncident, $config)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        $description = $this->incidentClassifier->extractIncidentDescription($latestIncident, $config);
        $fullText = $title . ' ' . $description;

        if ($this->incidentClassifier->isResolvedIncidentText($fullText)) {
            return ['indicator' => 'none', 'description' => 'All Systems Operational'];
        }

        if ($this->incidentClassifier->isMajorIncident($latestIncident, $config, $fullText)) {
            return ['indicator' => 'major', 'description' => 'Major Outage'];
        }

        return ['indicator' => 'minor', 'description' => 'Partially Degraded Service'];
    }
}

/**
 * Resolves and filters incident collections from API payloads.
 */
class ExternalServicesJsonIncidentsResolver
{
    /**
     * @param array $data Parsed API payload
     * @param array $config Parser configuration
     * @return array Filtered incident list
     */
    public function getConfiguredIncidents(array $data, array $config): array
    {
        $incidents = $data;

        if (isset($config['incidents_path'])) {
            $incidents = $this->resolveIncidentsPath($data, (string)$config['incidents_path']);
        }

        if (empty($incidents) || !is_array($incidents)) {
            return [];
        }

        return $this->filterIncidents($incidents, $config);
    }

    /**
     * @param array $data Parsed API payload
     * @param string $incidentsPath Dotted path to incidents data
     * @return array Resolved incidents
     */
    private function resolveIncidentsPath(array $data, string $incidentsPath): array
    {
        $incidents = $data;

        foreach (explode('.', $incidentsPath) as $key) {
            if (!is_array($incidents) || !isset($incidents[$key])) {
                return [];
            }

            $incidents = $incidents[$key];
        }

        return is_array($incidents) ? $incidents : [];
    }

    /**
     * @param array $incidents Incident list
     * @param array $config Parser configuration
     * @return array Filtered incident list
     */
    private function filterIncidents(array $incidents, array $config): array
    {
        if (!isset($config['filter_field']) || !isset($config['filter_value'])) {
            return $incidents;
        }

        $filtered = array_filter($incidents, function ($incident) use ($config) {
            return is_array($incident) && $this->incidentMatchesFilter($incident, $config);
        });

        return empty($filtered) ? [] : $filtered;
    }

    /**
     * @param array $incident Incident payload
     * @param array $config Parser configuration
     * @return bool
     */
    private function incidentMatchesFilter(array $incident, array $config): bool
    {
        $filterValue = $config['filter_value'];

        if (is_array($filterValue)) {
            foreach ($filterValue as $field => $value) {
                if (!isset($incident[$field]) || $incident[$field] !== $value) {
                    return false;
                }
            }

            return true;
        }

        $filterField = (string)$config['filter_field'];

        return isset($incident[$filterField]) && $incident[$filterField] === $filterValue;
    }
}

/**
 * Classifies incidents by recency, severity and textual markers.
 */
class ExternalServicesJsonIncidentClassifier
{
    /**
     * @param array $incident Incident data
     * @param array $config Parser configuration
     * @return string
     */
    public function extractIncidentTitle(array $incident, array $config): string
    {
        if (isset($config['title_parser']) && is_callable($config['title_parser'])) {
            $customTitle = $config['title_parser']($incident);
            if (is_string($customTitle)) {
                $customTitle = trim($customTitle);
                if ($customTitle !== '') {
                    return $customTitle;
                }
            }
        }

        if (!isset($config['title_field']) || !isset($incident[$config['title_field']])) {
            return '';
        }

        return trim((string)$incident[$config['title_field']]);
    }

    /**
     * @param array $incident Incident data
     * @param array $config Parser configuration
     * @return string
     */
    public function extractIncidentDescription(array $incident, array $config): string
    {
        if (!isset($config['description_field']) || !isset($incident[$config['description_field']])) {
            return '';
        }

        return (string)$incident[$config['description_field']];
    }

    /**
     * @param array $incident Incident data
     * @param array $config Parser configuration
     * @return bool
     */
    public function isIncidentRecent(array $incident, array $config): bool
    {
        if (!isset($config['timestamp_fields']) || !is_array($config['timestamp_fields'])) {
            return true;
        }

        $incidentDate = $this->extractIncidentTimestamp($incident, $config['timestamp_fields']);

        if ($incidentDate === null) {
            return true;
        }

        return (time() - $incidentDate) <= 86400;
    }

    /**
     * @param string $text Combined incident text
     * @return bool
     */
    public function isResolvedIncidentText(string $text): bool
    {
        return preg_match('/\b(resolved|completed|fixed|closed|ended|restored|operational)\b/i', $text) === 1;
    }

    /**
     * @param array $incident Incident data
     * @param array $config Parser configuration
     * @param string $fullText Combined title/description text
     * @return bool
     */
    public function isMajorIncident(array $incident, array $config, string $fullText): bool
    {
        if (preg_match('/outage|down|major|critical|offline/i', $fullText)) {
            return true;
        }

        if (!isset($config['severity_field']) || !isset($incident[$config['severity_field']])) {
            return false;
        }

        $severity = strtolower((string)$incident[$config['severity_field']]);

        return in_array($severity, ['high', 'critical', 'major'], true);
    }

    /**
     * @param array $incident Incident data
     * @param array $timestampFields Candidate timestamp fields
     * @return int|null
     */
    private function extractIncidentTimestamp(array $incident, array $timestampFields): ?int
    {
        foreach ($timestampFields as $field) {
            if (!isset($incident[$field])) {
                continue;
            }

            $timestamp = strtotime((string)$incident[$field]);
            if ($timestamp !== false) {
                return $timestamp;
            }
        }

        return null;
    }
}

/**
 * Catalog of dashboard services enabled in the external services settings UI.
 */
class ExternalServicesServiceCatalog
{
    private const HOSTING_SERVICES = [
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
        'wordpresscomapi' => true,
        'wpcloudapi' => true,
    ];

    private const DEVELOPER_TOOLS_SERVICES = [
        'codacy' => true,
        'github' => true,
        'gitlab' => true,
        'googleworkspace' => true,
        'notion' => true,
        'pipedream' => true,
        'trello' => true,
        'twilio' => true,
    ];

    private const ECOMMERCE_SERVICES = [
        'coinbase' => true,
        'intuit' => true,
        'metafb' => true,
        'paypal' => true,
        'recurly' => true,
        'shopify' => true,
        'square' => true,
        'stripe' => true,
        'woocommercepay' => true,
    ];

    private const EMAIL_SERVICES = [
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
    ];

    private const COMMUNICATION_SERVICES = [
        'discord' => true,
        'slack' => true,
        'zoom' => true,
    ];

    private const MEDIA_SERVICES = [
        'dropbox' => true,
        'reddit' => true,
        'spotify' => true,
        'udemy' => true,
        'vimeo' => true,
        'wistia' => true,
    ];

    private const AI_SERVICES = [
        'anthropic' => true,
        'openai' => true,
    ];

    private const ADVERTISING_SERVICES = [
        'googleads' => true,
        'metafbs' => true,
        'metalogin' => true,
        'metamarketingapi' => true,
        'microsoftads' => true,
    ];

    private const SECURITY_SERVICES = [
        'letsencrypt' => true,
        'flare' => true,
    ];

    /**
     * Get external services configuration map.
     *
     * @return array<string, bool> Map of service identifiers to enabled status
     */
    public function getServicesConfig(): array
    {
        return array_merge(
            self::HOSTING_SERVICES,
            self::DEVELOPER_TOOLS_SERVICES,
            self::ECOMMERCE_SERVICES,
            self::EMAIL_SERVICES,
            self::COMMUNICATION_SERVICES,
            self::MEDIA_SERVICES,
            self::AI_SERVICES,
            self::ADVERTISING_SERVICES,
            self::SECURITY_SERVICES
        );
    }
}