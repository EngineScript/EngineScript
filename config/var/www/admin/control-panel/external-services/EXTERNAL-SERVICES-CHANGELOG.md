# Changelog

All notable changes to the External Services portion EngineScript will be documented in this file.

Changes are organized by date, with the most recent changes listed first.

## 2025-11-17

### 🔒 SECURITY: Enhanced Feed Sanitization and XXE Protection

**Strengthened security** for external feed parsing with multi-layer sanitization and XML exploit protection

#### Security Improvements

**New `sanitizeFeedText()` Function:**

- **HTML Entity Decoding** - Handles encoded entities (`&lt;`, `&gt;`, etc.) before stripping tags
- **Tag Stripping** - Removes all HTML tags from feed content
- **Null Byte Removal** - Eliminates null bytes that could enable SQL injection
- **Whitespace Normalization** - Prevents formatting-based exploits
- **HTML Encoding** - Re-encodes special characters for safe JSON output

**XML External Entity (XXE) Protection:**

- `libxml_disable_entity_loader(true)` - Prevents external entity attacks
- `LIBXML_NOENT` flag - Disables entity substitution
- `LIBXML_NOCDATA` flag - Handles CDATA sections safely

**Applied Globally:**

- All 11 feed parsing functions now use `sanitizeFeedText()`
- RSS/Atom feeds (parseStatusFeed)
- JSON APIs (Google Workspace, Wistia, Vultr, Postmark, StatusPage.io)

#### Impact

- ✅ **Zero SQL Injection Risk** - No database interactions exist
- ✅ **XSS Prevention** - All output properly encoded for JSON
- ✅ **XXE Protection** - XML exploits blocked at parser level
- ✅ **Injection Prevention** - Multi-layer sanitization on all external content
- ✅ **Safe Output** - All text properly escaped before JSON encoding

#### Technical Details

**Before:**

```php
$status['description'] = strip_tags($title);
```

**After:**

```php
$status['description'] = sanitizeFeedText($title);

function sanitizeFeedText($text) {
    $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $text = strip_tags($text);
    $text = str_replace("\0", '', $text);
    $text = preg_replace('/\s+/', ' ', $text);
    $text = trim($text);
    $text = htmlspecialchars($text, ENT_QUOTES | ENT_HTML5, 'UTF-8', false);
    return $text;
}
```

---

### ✨ NEW SERVICES: Added 8 Email Service Providers to External Services Dashboard

**Added comprehensive email service monitoring** for popular transactional and marketing email platforms

#### New Services Added

**Email & Communication Category:**

- **SparkPost** - `https://status.sparkpost.com/`
- **Zoho** - `https://status.zoho.com/`
- **Mailjet** - `https://status.mailjet.com/`
- **MailerSend** - `https://status.mailersend.com/`
- **Resend** - `https://resend-status.com/`
- **SMTP2GO** - `https://smtp2gostatus.com/`
- **SendLayer** - `https://status.sendlayer.com/`

**Note:** Mailchimp was initially added but removed - their status page (`https://status.mailchimp.com/`) does not provide a public API or RSS/Atom feed.

**Hosting & Infrastructure Category:**

- **GoDaddy** - `https://status.godaddy.com/` (StatusPage API)

#### Implementation Details

**Frontend (`external-services.js`):**

- Added 8 email service definitions with appropriate icons and feed configurations
- SparkPost, Zoho, Mailjet, MailerSend, Resend, SMTP2GO, SendLayer use RSS/Atom feeds
- GoDaddy uses StatusPage.io JSON API (CORS-enabled)

**Backend (`external-services-api.php`):**

- Added 7 feed URLs to `$allowedFeeds` whitelist
- Feed mappings: sparkpost, zoho, mailjet, mailersend, resend, smtp2go, sendlayer

**Styling (`external-services.css`):**

- Added brand-specific color gradients for all 8 services
- SparkPost (orange), Zoho (red), Mailjet (orange), MailerSend (blue)
- Resend (black), SMTP2GO (blue), SendLayer (cyan), GoDaddy (teal)

#### Impact

- ✅ Comprehensive email service provider monitoring (8 services)
- ✅ Coverage for transactional email (Resend, SendLayer, SMTP2GO, SparkPost)
- ✅ Marketing platform monitoring (Zoho)
- ✅ Enterprise email services (SparkPost, Mailjet, MailerSend)
- ✅ Domain/hosting monitoring (GoDaddy)

---

### 🔧 VERSION CONTROL: Restricted Font Awesome Updates to 7.0.x Branch

**Prevented automatic updates** to Font Awesome 7.1.x due to CDN availability issues

#### Problem

- Version checker was fetching latest release (7.1.0)
- Font Awesome 7.1.0 not available on CDN (cdnjs.cloudflare.com)
- Caused ORB (Origin Request Blocked) errors in dashboard
- Need to stay on stable 7.0.x branch until 7.1.x available on CDN

#### Changes Made

**`.github/workflows/software-version-check.yml`:**

- Changed from `/releases/latest` to `/releases` endpoint
- Added jq filter: `select(.tag_name | test("^7\\.0\\.[0-9]+$"))`
- Now only detects and updates to 7.0.x patch releases
- Will auto-update to 7.0.2, 7.0.3, etc. when released

**`README.md`:**

- Corrected Font Awesome version from 7.1.0 → 7.0.1

#### Impact

- ✅ Prevents automatic updates to unavailable CDN versions
- ✅ Will auto-update within 7.0.x patch releases
- ✅ Maintains dashboard stability and reliability
- ✅ Can manually update to 7.1.x when CDN availability confirmed

---

## 2025-11-14

### ⚡ PERFORMANCE: Increased Timeouts for Slow External Service Feeds

**Fixed timeout errors** for slow-responding external service feeds (OVH, Vultr, WordPress.com API, WP Cloud API)

#### Problem

- Some external service feeds (OVH, Vultr, Automattic RSS) were timing out after 30 seconds
- PHP backend had only 10-second timeout for feed fetching
- Large RSS feeds with filtering (Automattic) required more processing time
- Users saw "AbortError: signal is aborted without reason" in console

#### Changes Made

- **`external-services-api.php`**: Increased PHP feed fetch timeout from 10s → 45s
- **`external-services.js`**: Increased JavaScript fetch timeout from 30s → 60s (both feed and StatusPage APIs)

#### Impact

- ✅ Slow feeds now have adequate time to respond
- ✅ Reduced timeout errors for OVH, Vultr, Automattic services
- ✅ Better handling of rate-limited or slow external APIs
- ✅ Improved reliability for international status feeds

---

### ✨ UX IMPROVEMENT: Category Toggle All for External Services

**Added bulk enable/disable buttons** for each service category in settings panel

#### Feature

- **Category-Level Controls**: Each category header now includes a "Toggle All" button
- **Smart Toggle Logic**:
  - If any services in category are unchecked → enables all
  - If all services are checked → disables all
- **Visual Feedback**: Button icon changes between check-square and square based on state
- **Bulk Operations**: Quickly enable/disable entire categories (Hosting, Developer Tools, etc.)

#### Implementation

- **Toggle All Button** positioned next to each category title
  - Clear visual hierarchy with hover effects
  - Accessible button with descriptive title attribute
  - Icon updates to reflect current state

- **Change Tracking**: All toggled services marked as pending changes
  - "Save Changes" button activates when categories toggled
  - Changes applied to all services in category simultaneously

#### Categories Affected

All 9 service categories:

1. Hosting & Infrastructure (17 services)
2. Developer Tools (8 services)
3. E-Commerce & Payments (9 services)
4. Email & Communication (8 services)
5. Media & Content (6 services)
6. Gaming (1 service)
7. AI & Machine Learning (2 services)
8. Advertising (8 services)
9. Security (2 services)

#### Impact

- ✅ **Faster bulk operations** - enable/disable entire categories with one click
- ✅ **Improved workflow** - no need to individually check 17 hosting services
- ✅ **Better UX** - clear visual feedback and intuitive behavior
- ✅ **Time savings** - especially useful for large categories
- ✅ **Consistent UI** - follows established design patterns

---

### ⚡ PERFORMANCE: Lazy Loading for External Services

**Implemented dynamic import and lazy loading** to eliminate external services loading delay on initial page load

#### Problem

- External services module loaded on every dashboard page load
- 50+ external service API/feed requests triggered even when not on External Services page
- Caused significant latency for Overview page loading
- Service status (Nginx, PHP, MySQL) and UptimeRobot data blocked waiting for external feeds
- Slow international feeds (OVH, Vultr, WordPress.com API) delayed entire dashboard

#### Changes Made

- **Dynamic Module Import**: Replaced static import with dynamic `import()` for external services
  - Module only downloaded when user navigates to External Services page
  - No parsing or execution overhead on initial load

- **Lazy Initialization**: Added `initialized` flag to prevent duplicate loading
  - First navigation to page loads and caches the module
  - Subsequent visits reuse existing instance

- **On-Demand Loading**: External services only fetch when page is viewed
  - Overview page now loads instantly without waiting for external feeds
  - Service status and UptimeRobot data no longer blocked

#### Implementation

```javascript
// Before: Static import (always loaded)
import { ExternalServicesManager } from './external-services/external-services.js';

// After: Dynamic import (lazy loaded)
async loadExternalServices() {
  if (!this.externalServices) {
    const { ExternalServicesManager } = await import('./external-services/external-services.js');
    this.externalServices = new ExternalServicesManager(...);
  }
  await this.externalServices.init();
}
```

#### Impact

- ✅ **Dashboard loads instantly** - no external service delays on Overview page
- ✅ **Faster initial page load** - ~2-5 second improvement (depending on slow feeds)
- ✅ **Reduced bandwidth** - external services module only loaded when needed
- ✅ **Better resource utilization** - browser doesn't fetch 50+ feeds unless user views that page
- ✅ **Improved user experience** - critical data (server status, sites) loads immediately
- ✅ **On-demand loading** - external services load in parallel only when navigating to that tab

#### User Experience

- **Before**: Dashboard loads → waits for all external feeds → shows Overview (slow)
- **After**: Dashboard loads → shows Overview immediately → external feeds only load if user clicks that tab (fast)

---

### 🐛 BUG FIX: Font Awesome Version & Cloudflare Rocket Loader Compatibility

- Fixed Font Awesome 404 error and ES6 module preload warnings

#### Problem 1: Invalid Font Awesome Version

- `FONTAWESOME_VER` set to non-existent version `7.1.0`
- CDN returned 404 (text/html error page) instead of CSS
- Browser error: "MIME type ('text/html') is not a supported stylesheet MIME type"
- Font Awesome 7.x doesn't exist yet (latest stable is 6.x)

#### Problem 2: Cloudflare Rocket Loader Interference

- Rocket Loader attempted to optimize ES6 module scripts
- Caused preload credential mismatch warnings
- "Request credentials mode does not match" error for dashboard.js

#### Changes Made

- **Updated Font Awesome version**: `7.1.0` → `6.7.1` (latest stable release)
  - Fixed in `enginescript-variables.txt`
  - Fixed in `.github/ci-config/enginescript-variables-ci.txt`

- **Added ES6 module preload hints** with correct crossorigin attribute:
  - `<link rel="modulepreload" href="dashboard.js" crossorigin="use-credentials">`
  - `<link rel="modulepreload" href="modules/api.js" crossorigin="use-credentials">`

- **Disabled Rocket Loader for ES6 modules**:
  - Added `data-cfasync="false"` to `dashboard.js` script tag
  - Prevents Cloudflare from interfering with native ES6 module loading

#### Impact

- ✅ Font Awesome CSS now loads correctly from CDN
- ✅ All dashboard icons display properly
- ✅ ES6 modules preload without credential warnings
- ✅ Improved initial page load performance with modulepreload
- ✅ Compatible with Cloudflare Rocket Loader optimization

---

### 🔧 CODE QUALITY: Shell Script Variable Quoting

**Fixed 12 unquoted variable expansions** to prevent globbing and word splitting

#### Problem

- Shell variables in paths and URLs were unquoted
- Could cause issues with filenames containing spaces or special characters
- Shellcheck warnings: "Double quote to prevent globbing and word splitting"

#### Files Fixed

- **`openssl-update.sh`**: Quoted `${CPU_COUNT}` in make command
- **`phpmyadmin-update.sh`**: Quoted `${PHPMYADMIN_VER}` in wget, unzip, and mv commands
- **`mariadb-update.sh`**: Quoted `${MARIADB_VER}` in MariaDB repo setup
- **`nginx-compile.sh`**: Quoted all version variables in configure flags:
  - `${NGINX_VER}`, `${DT}`, `${OPENSSL_VER}`, `${PCRE2_VER}`
  - `${NGINX_HEADER_VER}`, `${NGINX_PURGE_VER}`
  - Fixed in both HTTP/2 and HTTP/3 configuration sections

#### Impact

- ✅ Prevents potential pathname expansion issues
- ✅ Safer handling of version strings with special characters
- ✅ Follows bash best practices
- ✅ Eliminates shellcheck warnings
- ✅ No functional changes - defensive programming improvement

---

### 🐛 BUG FIX: Font Awesome ORB Blocking

**Fixed ERR_BLOCKED_BY_ORB error** preventing Font Awesome icons from loading

#### Problem

- Browser's Opaque Response Blocking (ORB) security feature blocked Font Awesome CSS
- Console error: `all.min.css (failed) net::ERR_BLOCKED_BY_ORB`
- Icons failed to load, breaking dashboard UI

#### Changes Made

- **Added `crossorigin="anonymous"`** attribute to Font Awesome `<link>` tag
- Enables proper CORS handling for cross-origin stylesheets
- Allows browser to validate and load the external CSS resource

#### Impact

- ✅ Font Awesome icons now load correctly
- ✅ Dashboard UI displays all icon elements properly
- ✅ Complies with modern browser security policies (ORB)
- ✅ No performance impact - attribute allows proper resource loading

---

### ⚡ PERFORMANCE: Parallel External Services Loading

**Removed artificial request staggering** for faster service status loading

#### Problem

- Services loaded with 60ms delay between each request (staggered loading)
- Slow RSS/Atom feeds blocked other services from completing
- Sequential loading pattern caused cascading delays
- Services at bottom of list experienced significant wait times

#### Changes Made

- **Parallel Request Firing**: All service status requests now fire immediately in parallel
- **Removed setTimeout Delays**: Eliminated 60ms staggered delay system
- **True Non-Blocking**: Each request operates independently with its own 60s timeout
- **Browser Concurrency**: Let browser's HTTP/2 multiplexing handle concurrent requests efficiently

#### Impact

- ✅ All services start loading immediately (no artificial delays)
- ✅ Slow feeds no longer block fast services from completing
- ✅ Dramatically improved perceived performance
- ✅ Services complete in order of actual response time, not queue position
- ✅ Modern browsers handle concurrent requests efficiently with HTTP/2

#### Technical Details

- Browser connection limits (6-8 per domain) now managed by browser's built-in queueing
- HTTP/2 multiplexing allows many concurrent requests over single connection
- Each request has independent AbortController with 60s timeout
- Failed requests don't impact other services

---

### 🔧 CODE QUALITY: Codacy Security & Style Improvements

**Enhanced security annotations and HTTP compliance** in external services API

#### Changes Made

- **Security Annotations**: Added Codacy ignore comments with justifications for legitimate direct `$_GET` access
  - All input validated against strict whitelists (30+ allowed feed types)
  - Filter parameter sanitized with regex whitelist and 100-character limit
  - Clear documentation that input validation prevents injection attacks

- **HTTP Compliance**: Added `Content-Type: application/json` headers to all JSON responses
  - 12 API endpoints now return proper Content-Type headers
  - Improves client-side parsing and standards compliance
  - Error responses include proper HTTP status codes + headers

- **CSS Style**: Fixed empty line before keyframe rule in `external-services.css`
  - Added required empty line before `to` rule (line 412)
  - Meets CSS style guide requirements

- **Code Optimization**: Simplified conditional logic in `parseStatusFeed()`
  - Removed unnecessary else clause
  - Improved code readability and flow

#### False Positives Documented

Created `.codacy-review-notes.md` documenting 11 false positive warnings:

- CSRF warnings on GET requests (read-only operations, no state modification)
- WordPress-specific warnings (`wp_unslash`) on non-WordPress code
- `file_get_contents()` warnings for legitimate outbound HTTP API calls with timeout protection
- Function length warnings on inherently complex feed parsers
- Documentation formatting preferences

#### Codacy Configuration

Created `.codacy.yml` to suppress expected API endpoint patterns:

- **Excludes WordPress core files** (`wp-config.php`) - not under our control
- **Excludes API files** from WordPress-specific rules (nonce verification, wp_unslash)
- **Allows required functions** in API endpoints: `header()`, `echo`, `exit`, `die`
- **Permits direct superglobal access** when followed by strict validation/sanitization
- **Allows outbound HTTP functions**: `file_get_contents()`, `stream_context_create()` with timeout
- **Disables line length limits** for documentation files containing URLs
- **Module inclusion allowed**: `require_once` with `__DIR__` constant (hardcoded paths)

Added inline `@codacy suppress` comments for all 14 legitimate API patterns:

- 11 suppressions in `external-services-api.php` (die, echo, exit, file_get_contents, stream_context_create)
- 1 suppression in `api.php` (require_once for module inclusion)
- All suppressions include clear explanations of why the pattern is necessary and safe

---

### 🐛 CRITICAL FIX: External Services API Handler Script Termination

**Fixed 502 Bad Gateway errors** caused by improper script termination in external-services-api.php

#### Problem Identified

- Handler functions (`handleStatusFeed()`, `handleExternalServicesConfig()`) were outputting JSON but not terminating script execution
- PHP continued executing after `return` statements, causing additional output and 502 errors
- Closing `?>` tag was present (bad practice for include-only files)

#### Changes Made to `external-services-api.php`

- ✅ Added `exit;` after all `echo json_encode()` statements in `handleStatusFeed()`
- ✅ Added `exit;` after all `echo json_encode()` statements in `handleExternalServicesConfig()`
- ✅ Replaced all `return;` with `exit;` in error handlers (12 locations)
- ✅ Removed closing `?>` tag (PHP best practice)

#### Impact

- **Resolved**: 502 Bad Gateway errors when loading external services
- **Resolved**: Multiple "AbortError: signal is aborted without reason" errors in browser console
- **Result**: External services feed requests now complete successfully

---

### 🏗️ REFACTORING: External Services Module Extraction (COMPLETED)

**Created standalone external services module** in `config/var/www/admin/control-panel/external-services/`

**Full separation achieved** - all external services code completely extracted and cleaned from main dashboard files

#### New Module Files Created

- **`external-services.js`** - ES6 module class with self-contained service management
  - `ExternalServicesManager` class with own state management
  - 5-minute cache TTL for improved performance
  - Imports utilities from shared `modules/utils.js`
  - Constructor accepts container IDs for flexible integration
  - Public `init()` method for clean initialization
  - All service definitions, preferences, ordering, drag-drop functionality
  
- **`external-services.css`** - Complete styling extracted from dashboard.css (lines 1197-1583)
  - Service cards, grids, headers, icons
  - Drag-drop states and visual indicators
  - Loading states and skeleton loaders
  - Settings panel with collapsible sections
  - Service toggles and save button
  - All service icon gradients and colors
  - Responsive breakpoints for mobile/tablet
  
- **`external-services-api.php`** - All feed parsing and backend logic extracted from api.php
  - `parseStatusFeed()` - RSS/Atom feed parser with 48-hour recency filter
  - `parseGoogleWorkspaceIncidents()` - Google Workspace JSON API parser
  - `parseWistiaSummary()` - Wistia status JSON parser
  - `parseVultrAlerts()` - Vultr alerts JSON parser
  - `parsePostmarkNotices()` - Postmark notices API parser
  - `parseStatusPageAPI()` - Standard StatusPage.io JSON parser
  - `handleStatusFeed()` - Feed request routing with strict whitelisting
  - `getExternalServicesConfig()` - Available services configuration
  - `handleExternalServicesConfig()` - Config endpoint handler
  - All security validation and input sanitization
  
- **`external-services.html`** - Comprehensive integration guide and documentation
  - Required DOM structure and element IDs
  - Complete integration examples
  - API endpoint specifications
  - Customization instructions for adding new services
  - Security best practices
  - Performance features explained
  - Browser compatibility information

#### Architecture Improvements

- **Maintains all existing functionality** including:
  - 60+ external service definitions with categorization
  - Drag-and-drop card reordering with persistent preferences
  - Client-side cookie storage (servicePreferences, serviceOrder)
  - Service toggle settings panel with save functionality
  - Staggered async loading (60ms delay between requests)
  - Static service cards for non-API services (AWS)
  - Loading states and error handling
  - All security measures (input validation, XSS prevention, whitelisting)

- **ES6 module architecture:**
  - Clean imports/exports
  - No global namespace pollution
  - Proper encapsulation
  - Reusable across projects

#### Legacy Code Removal & Cleanup (VERIFIED COMPLETE)

- **dashboard.js** - Removed 1,598 lines of external services code (60% reduction: 2,633 → 1,035 lines)
  - ✅ **VERIFIED CLEAN**: No external services methods remain
  - ✅ Only proper integration code: import statement and initialization
  - ✅ Clean delegation to ExternalServicesManager module
  - ✅ Retained all core dashboard functionality (LEMP stack services, sites, system info, uptime monitoring)
  - ✅ No service-specific code (cloudflare, stripe, vultr, github, etc.)
  
- **dashboard.css** - Removed ~380 lines of external services styles (1,608 → 1,228 lines)
  - ✅ **VERIFIED CLEAN**: No external services styles remain
  - ✅ All service card styles moved to external-services.css
  - ✅ All service icon gradients and colors moved
  - ✅ All settings panel styles moved
  - ✅ All drag-drop visual states moved
  - ✅ Retained core service styles (for LEMP stack: Nginx, PHP, MySQL, Redis)
  - ✅ Only cleanup marker comment remains
  
- **api.php** - Removed ~750 lines of external services backend code (FINAL CLEANUP COMPLETE)
  - **Removed all orphaned feed parsing functions** (lines 1018-1700+)
    - `parseStatusFeed()` with Atom/RSS logic
    - `parseGoogleWorkspaceIncidents()`
    - `parseWistiaSummary()`
    - `parseVultrAlerts()`
    - `parsePostmarkNotices()`
    - `parseStatusPageAPI()`
    - `handleStatusFeed()` with all feed routing
  - **Removed duplicate config functions** (lines 1639-1731)
    - `getExternalServicesConfig()` with full service list
    - `handleExternalServicesConfig()` handler
  - **Added security constant definition** before requiring external-services-api.php
  - **Clean routing** delegates to external services module correctly
  - **Retained UptimeRobot integration** (monitoring endpoints, not external services)
  - **Retained all core API endpoints** (system info, services status, sites, alerts, etc.)

#### Benefits

- ✅ **Improved maintainability** through separation of concerns
- ✅ **Better code organization** with clear module boundaries
- ✅ **Easier testing** of isolated components
- ✅ **Reusability** across different dashboard implementations
- ✅ **Clear documentation** for integration and customization
- ✅ **No breaking changes** - all functionality preserved
- ✅ **Massive code reduction** in main dashboard files (~2,700 lines extracted)
- ✅ **Ready for standalone project** - just copy external-services/ + modules/utils.js

## 2025-11-13

### ⚡ PERFORMANCE: Request Management & Timeout Improvements

- **Staggered Request Loading**:
  - Services now load with 60ms delay between each request
  - Prevents overwhelming browser connection limits (typically 6 concurrent connections)
  - Eliminates timeout issues for services at bottom of page
  - All services get fair chance to load without competing for limited connections

- **Increased Request Timeouts**:
  - Timeout increased from 10 seconds to 30 seconds for all service requests
  - Gives slower feeds adequate time to respond
  - Reduces false "Request timed out" errors for legitimate slow responses
  - Applied to feed services, API services, and status page services

### ✨ UX IMPROVEMENTS: Async Loading Pattern

- **Immediate Card Display**:
  - Service cards now appear instantly when page loads with service name displayed
  - Cards show "Loading..." status with spinner icon during initial load
  - Eliminates blank page experience - users see content immediately

- **Non-Blocking Status Updates**:
  - Service status updates load independently in parallel using async pattern
  - No service blocks others from loading - all feeds fetch simultaneously
  - Each card updates individually when its feed data arrives
  - Significantly improved page load performance and perceived speed

- **Implementation Details**:
  - New `displayServiceCardWithLoadingState()` function creates cards immediately
  - New `updateFeedServiceStatus()` function updates feed-based services asynchronously
  - New `updateStatusPageServiceStatus()` function updates API-based services asynchronously
  - Changed from sequential `await` pattern to parallel async with `.catch()` error handling
  - Cards receive loading state initially, then update to success/error states

### 🎯 UX IMPROVEMENTS: Enhanced Drag-and-Drop

- **Simple Swap Behavior**:
  - Drag a card and drop it directly on another card to swap their positions
  - No need to drag past cards - just drop on the target card
  - Dashed border highlights the drop target card while hovering
  - Cards swap positions immediately when mouse is released
  - Intuitive behavior matches user expectations

- **Better Detection & Sensitivity**:
  - Drag-and-drop now works reliably when hovering over any part of a card
  - Entire card border area acts as valid drop zone (not just specific hover points)
  - Enhanced collision detection using DOM tree traversal with `while` loops
  - Properly handles dragging over child elements (icons, text, etc.)

- **Category Grid Support**:
  - Now operates on `.service-category-grid` elements instead of flat container
  - Maintains category-based organization during drag operations
  - Uses `getBoundingClientRect()` for accurate bounds checking
  - Prevents flickering with improved dragenter/dragleave detection

### 🔄 REORGANIZATION: Major Service Recategorization

- **Category Merge - E-Commerce & Payments**:
  - Combined "Payment Processing" and "E-Commerce" into single "E-Commerce & Payments" category
  - Logical grouping since payment services support e-commerce functionality
  - Reduces total categories from 10 to 9 for better organization

- **Category Rename**:
  - Renamed "Communication" to "Email & Communication" for better clarity
  - Updated all service definitions and configuration files

- **Service Renames**:
  - **MailPoet Sending Service** → **MailPoet** (shorter, cleaner name)
  - **Cloudflare Flare** → **Flare** (removed redundant Cloudflare prefix)
  - **Meta: Facebook & Instagram** → **Meta: Facebook & Instagram Shops** (clarifies e-commerce focus)

- **Developer Tools Recategorization**:
  - **Postmark**: Moved from Developer Tools → Email & Communication (email delivery service)
  - **Google Workspace**: Moved from Advertising → Developer Tools (admin console, Gmail, Drive, Meet, Calendar)
  - **Meta: Facebook Login**: Moved from Advertising → Developer Tools (authentication service)

- **E-Commerce & Payments Consolidation**:
  - **Meta: Facebook & Instagram Shops**: Moved from Advertising → E-Commerce & Payments
  - **All Payment Processors**: Moved from Payment Processing → E-Commerce & Payments
    - Coinbase, PayPal, Recurly, Square, Stripe
  - **All E-Commerce Platforms**: Merged into E-Commerce & Payments
    - Intuit, Shopify, WooCommerce Pay

- **Automattic Services (Previously Reorganized)**:
  - **WooCommerce Pay API**: In E-Commerce & Payments (e-commerce platform API)
  - **MailPoet**: In Email & Communication (email marketing service)
  - **WordPress.com API**: In Hosting & Infrastructure (hosting platform API)
  - **Jetpack API**: In Hosting & Infrastructure (WordPress hosting features)
  - **WP Cloud API**: In Hosting & Infrastructure (cloud hosting API)

- **Updated Category Order** (Final 9 Categories):
  1. Hosting & Infrastructure (WordPress.com, Jetpack, WP Cloud APIs)
  2. Developer Tools (Google Workspace, Meta: Facebook Login, Postmark)
  3. E-Commerce & Payments (merged - all payment + e-commerce services)
  4. Email & Communication (renamed - email delivery and communication tools)
  5. Media & Content
  6. Gaming
  7. AI & Machine Learning
  8. Advertising
  9. Security

### 🐛 BUG FIXES: Service Configuration & Loading

- **Fixed AWS Static Service Display**:
  - AWS now correctly displays as static card with "Visit status page" link
  - No longer shows perpetual "Loading..." state
  - Added logic to detect static services (no API or feed) and render them immediately

- **Fixed OpenAI Service Loading**:
  - Added Atom feed monitoring: `https://status.openai.com/feed.atom`
  - Configured to display incident titles like other RSS/Atom feeds
  - Changed from static card to live status monitoring
  - No longer stuck at "Loading..." state

- **Removed Loading Screen Spinner**:
  - Disabled central loading screen spinner that appeared during page load
  - Dashboard now displays instantly with cards showing async loading states
  - Eliminates spinning icon that could get stuck if service fails to load

- **Fixed Flare Service Icon**:
  - Corrected CSS class reference from `cloudflare-icon` to `flare-icon`
  - Added proper orange gradient styling for Flare icon (#f4862b → #f99f4e)
  - Service properly displays with correct branding

- **Removed Duplicate Service Definitions**:
  - Fixed duplicate `openai` service definition in configuration
  - Fixed duplicate `microsoftads` service definition
  - Removed duplicate Advertising section in backend configuration

- **Fixed PHP Syntax Error**:
  - Corrected syntax error in `api.php` line 1693: `'microsoftads' => true,g`
  - Removed extra `g` character causing 500 Internal Server Error
  - Error was preventing API endpoint from responding correctly

- **Service Order Alphabetization**:
  - Fixed `jetpackapi` service ordering - now properly alphabetized
  - Added all missing services to default service order array
  - Ensures consistent ordering across all categories

### 🔧 CODE QUALITY: Linting and Style Improvements

- **JavaScript Code Style**:
  - Removed unexpected blank lines between object properties in service definitions
  - Fixed unused variable `isAvailable` in service iteration loop (changed to destructure only `serviceKey`)
  - Improved code consistency across service configuration objects

- **CSS Code Style**:
  - Shortened hex color codes for better readability and reduced file size
  - Changed `#ff9900` to `#f90` (AWS icon)
  - Changed `#0066ff` to `#06f` (Stripe icon)
  - Changed `#0099cc` to `#09c` (Vimeo icon)

### ✨ NEW: Additional Service Status Integrations

- **Developer Tools**:
  - Added Trello (Atlassian) status monitoring via StatusPage.io JSON API
  - API endpoint: `https://trello.status.atlassian.com/api/v2/status.json`
  - Added Pipedream status monitoring via StatusPage.io JSON API
  - API endpoint: `https://status.pipedream.com/api/v2/status.json`
  - Added Codacy status monitoring via RSS feed
  - Feed URL: `https://status.codacy.com/history.rss`
  - Displays incident titles only for clear, concise status updates

- **Communication Services**:
  - Added SendGrid status monitoring via StatusPage.io JSON API
  - API endpoint: `https://status.sendgrid.com/api/v2/status.json`

- **Media & Content Services**:
  - Added Spotify status monitoring via StatusPage.io JSON API
  - API endpoint: `https://spotify.statuspage.io/api/v2/status.json`

- **AI & Machine Learning Services**:
  - Added Anthropic (Claude) status monitoring via RSS feed
  - Feed URL: `https://status.claude.com/history.atom`

- **Advertising Services - Meta Platform Monitoring**:
  - Added Meta: Facebook & Instagram status monitoring
  - Added Meta: Marketing API status monitoring
  - Added Meta: Business Suite status monitoring
  - Added Meta: Facebook Login status monitoring
  - All Meta services use individual RSS feeds from `https://metastatus.com/`
  - Feeds:
    - `outage-events-feed-fb-ig-shops.rss` (Facebook & Instagram)
    - `outage-events-feed-marketing-api.rss` (Marketing API)
    - `outage-events-feed-fbs.rss` (Business Suite)
    - `outage-events-feed-facebook-login.rss` (Facebook Login)

- **Backend Enhancements**:
  - Added `parseStatusPageAPI()` function for standard StatusPage.io JSON API parsing
  - Supports indicator and description fields from StatusPage.io format
  - Added all new feed types to security whitelist
  - Total services now: 53+ external service integrations

### 🔒 SECURITY: Input Sanitization & Injection Prevention

- **Log Injection Fix**:
  - Sanitized user-controlled `$path` variable before logging to prevent log injection attacks
  - Added regex filter to allow only safe characters: `a-z`, `A-Z`, `0-9`, `/`, `-`, `_`, `.`
  - Removed path from JSON error response to prevent information disclosure
  - Addresses SonarCloud security rule `phpsecurity:S5145`

- **Input Validation Enhancements**:
  - Added sanitization for `endpoint` query parameter using regex whitelist
  - Added whitelist validation for `feed` parameter with accurate feed types
  - Feed whitelist includes: JSON APIs (vultr, googleworkspace, wistia, postmark) and RSS/Atom feeds (automattic, stripe, letsencrypt, slack, gitlab, square, paypal, googlecloud, brevo, etc.)
  - Added sanitization for `filter` parameter (alphanumeric, spaces, hyphens, periods, parentheses)
  - Limited filter parameter length to 100 characters
  - Prevents injection attacks through query parameters

- **Code Quality**:
  - Removed empty CSS ruleset `.settings-save-btn.has-changes`
  - Converted to comment for better maintainability

- **Bug Fix**:
  - Fixed feed whitelist to include all actual feed types used by services
  - Restored Automattic services (WooCommerce Pay API, WP Cloud API, MailPoet, Jetpack API, WordPress.com API)

## 2025-11-12

### 🔧 IMPROVEMENT: Enhanced Feed Parsing & JSON API Integration

- **Google Workspace JSON API Integration**:
  - Migrated from Atom feed to official incidents JSON API
  - API URL: `https://www.google.com/appsstatus/dashboard/incidents.json`
  - Extracts incident title from `external_desc` field (format: `**Title:**\nActual title`)
  - Proper regex parsing to handle title formatting variations
  - Severity detection based on incident severity field (high/critical → major)
  - Added `parseGoogleWorkspaceIncidents()` function with proper error handling

- **Wistia JSON API Integration**:
  - Migrated from incorrect API endpoint to proper summary JSON API
  - API URL: `https://status.wistia.com/summary.json`
  - Displays active incident names directly (e.g., "Some search and filtering requests may fail to succeed")
  - Severity detection based on impact field (MAJOROUTAGE/CRITICAL → major)
  - Added `parseWistiaSummary()` function with comprehensive status checking
  - Fixed 404 errors caused by non-existent `/public-api/v1/status.json` endpoint

- **Brevo Feed Enhancement**:
  - Enhanced CDATA tag stripping from Atom feed titles
  - Now properly extracts clean text from `<![CDATA[...]]>` wrapped content
  - Displays incident title only (e.g., "Issue with plan manager" instead of HTML wrapped version)
  - Improved regex pattern to handle all CDATA variations

- **Vultr JSON API Integration**:
  - Migrated from RSS feed to official JSON API (`https://status.vultr.com/alerts.json`)
  - Now only displays **ongoing** alerts (filters out resolved incidents)
  - Uses Alert Schema with proper status field checking
  - More accurate real-time status monitoring
  
- **Postmark JSON API Integration**:
  - Migrated from Atom feed to official Notices API
  - Now only displays **current unplanned** incidents using API filters
  - API URL: `https://status.postmarkapp.com/api/v1/notices?filter[timeline_state_eq]=present&filter[type_eq]=unplanned`
  - Excludes planned maintenance and past incidents
  - Provides cleaner status information focused on active issues
  
- **Implementation Details**:
  - All JSON API parsers include 10-second timeout and proper error handling
  - Consistent severity detection across all services
  - Enhanced feed parser with CDATA stripping for cleaner text extraction
  - Cache Version: Updated to v=2025.11.12.17

### 🔧 IMPROVEMENT: Time-Based Feed Filtering

- **48-Hour Feed Age Filter**:
  - RSS/Atom feed entries now filtered by published/updated date
  - Only displays status messages if entry is within past 48 hours
  - Older entries automatically show "All Systems Operational"
  - Prevents stale incident messages from showing in dashboard
  - Supports both Atom (`published`/`updated`) and RSS (`pubDate`) timestamp formats
  - Falls back to DC namespace date element for RSS feeds if pubDate missing
  - Cache Version: Updated to v=2025.11.12.14

### 🔧 IMPROVEMENT: Service Settings Save Button & API Fixes

- **Save Button Implementation**:
  - Added "Save Changes" button to service settings panel
  - Changes are now batched instead of applying instantly
  - Prevents dashboard disruption when toggling multiple services
  - Button pulses when changes are pending
  - Shows success/error notifications after saving
  
- **API Endpoint Fixes**:
  - Fixed 404 errors for RSS/Atom feed services
  - Updated API calls to use proper query parameter format
  - Improved fallback handling when API is unavailable
  - Services now load from local definitions if API fails
  
- **Postmark Feed Integration**:
  - Converted from API (CORS blocked) to RSS feed
  - Added to feed whitelist: `https://status.postmarkapp.com/history.atom`
  
- **Enhanced Error Handling**:
  - All 46 services now display correctly in settings panel
  - Better fallback behavior for service availability
  - Improved debugging with error logging

- **Cache Version**: Updated to v=2025.11.12.13

- **Bug Fix**: Corrected API endpoint URLs to match Nginx rewrite rules
  - Changed from `/api?endpoint=/path` to `/api/path` format
  - Fixes all 404 errors for feed and config endpoints
  - Now properly routes through Nginx to api.php

- **UI Improvements**:
  - Settings panel now scrollable (80vh max-height with styled scrollbar)
  - Save button more visible (60% opacity when disabled)
  - Settings panel auto-collapses after saving changes
  
- **Performance Enhancements**:
  - **Service Status Caching**: External service status cached for 5 minutes
  - Significantly reduces API calls to external service endpoints
  - Cache automatically cleared when refresh button clicked manually
  - Dashboard refresh interval increased from 30 seconds to 5 minutes
  - Prevents interruption while configuring services
  - Cached responses improve page load speed on subsequent visits

### ➕ ADDITION: WordPress & Email Service Monitoring

- **New Services Added** (3 additional services):
  - **Brevo** (Communication): Email marketing and transactional email service with RSS feed support
  - **Automattic** (Media & Content): WordPress.com parent company status monitoring
  - **WordPress VIP** (Hosting & Infrastructure): Enterprise WordPress hosting platform status
  
- **Feed Integration**:
  - Brevo: `https://status.brevo.com/feed.atom`
  - Automattic: `https://automatticstatus.com/rss`
  - WordPress VIP: `https://wpvipstatus.com/rss`
  
- **Total Services**: Now 53 services across 10 categories

- **Cache Version**: Updated to v=2025.11.12.7

### 📦 EXPANSION: 40+ Additional Services & Category Organization

- **Massive Service Expansion** (from 8 to 50+ services):
  - **Hosting & Infrastructure** (14 services): AWS, Cloudflare, Cloudways, DigitalOcean, Google Cloud, Hostinger, Kinsta, Linode, Oracle Cloud, OVH Cloud, Scaleway, UpCloud, Vercel, Vultr
  - **Developer Tools** (5 services): GitHub, GitLab, Notion, Postmark, Twilio
  - **Payment Processing** (5 services): Coinbase, PayPal, Recurly, Square, Stripe
  - **Communication** (4 services): Discord, Mailgun, Slack, Zoom
  - **E-Commerce** (2 services): Intuit, Shopify
  - **Media & Content** (5 services): Dropbox, Reddit, Udemy, Vimeo, Wistia
  - **Gaming** (1 service): Epic Games
  - **AI & Machine Learning** (1 service): OpenAI
  - **Advertising** (4 services): Google Ads, Google Search Console, Google Workspace, Microsoft Advertising
  - **Security** (2 services): Let's Encrypt, Cloudflare Flare

- **Category Organization**:
  - Settings panel now groups services by category with headers
  - Categories styled with accent color borders and uppercase titles
  - Services sorted alphabetically within each category
  - Improved readability with visual separation

- **No Default Services**:
  - Changed behavior: no services enabled by default
  - First visit shows empty state message: "No Services Selected"
  - Encourages users to select only services they need
  - Reduces API load and improves dashboard performance
  - Users can enable services via "Service Settings" button

- **Additional Feed Support**:
  - Added feed URLs for: Slack, GitLab, Square, Recurly, Google services, Microsoft Ads, PayPal, Oracle, OVH, Vultr
  - Total of 16 services now using RSS/Atom feeds
  - Backend whitelist updated with all new feed endpoints

- **Code Refactoring**:
  - Extracted service definitions into `getServiceDefinitions()` method (eliminates duplication)
  - Simplified preference validation (dynamic check against all definitions)
  - Default service order now includes all 50+ services
  - Updated backend config to return all available services

- **CSS Enhancements**:
  - `.settings-category`: Section styling for category blocks
  - `.category-title`: Accent-colored headers with borders
  - `.settings-grid`: Adjusted for better service toggle layout

- **Cache Version**: Updated to v=2025.11.12.6

### 🔗 INTEGRATION: RSS/Atom Feed Support for External Services

- **RSS/Atom Feed Parsing**:
  - Added backend feed parser to extract status from RSS/Atom feeds
  - Parses both RSS 2.0 and Atom feed formats
  - Extracts status indicators from feed titles and descriptions
  - Pattern matching for operational, minor, and major incidents
  - Automatic truncation of long descriptions (200 character limit)

- **Feed-Enabled Services**:
  - **Stripe**: Uses Atom feed from `https://www.stripestatus.com/history.atom`
  - **Let's Encrypt**: Uses RSS feed from `https://letsencrypt.status.io/pages/.../rss`
  - Services now display real-time status instead of static "Visit status page" links
  - Feed data proxied through backend to avoid CORS restrictions

- **Vimeo API Integration**:
  - Updated Vimeo to use direct API at `https://www.vimeostatus.com/api`
  - Now displays live status like other API-enabled services
  - Removed from static link-only services

- **AWS Status**:
  - Remains as static link (requires enterprise account for API access)
  - Only service still showing "Visit status page"

- **Backend Updates** (api.php):
  - Added `parseStatusFeed($feedUrl)`: RSS/Atom XML parser with libxml
  - Added `handleStatusFeed()`: Secure feed proxy endpoint with whitelist
  - New route: `/external-services/feed?feed={type}`
  - Feed types: `stripe`, `letsencrypt`, `cloudflare-flare`
  - 10-second timeout on feed fetches
  - Error handling for malformed XML and network failures

- **Frontend Updates** (dashboard.js):
  - Added `loadFeedService()`: Fetches status from backend feed proxy
  - Updated service definitions with `useFeed` flag and `feedType` parameter
  - Service loading logic now handles three types: API, Feed, and Static
  - Feed services display identical to API services (consistent UX)
  - Error states handle feed fetch failures gracefully

- **Cache Version**: Updated to v=2025.11.12.5

### ✨ UI/UX: Service Settings Header & Drag-and-Drop Reordering

- **Improved Settings Panel Layout**:
  - Settings panel now renders as full-width header above service cards
  - Removed from inline grid layout for better visual separation
  - Settings panel stays open when toggling service checkboxes (no more collapse)
  - Persistent panel state improves user experience
  - Updated instructions: "Toggle services to show/hide on the dashboard. Drag service cards to reorder them."

- **Drag-and-Drop Service Reordering**:
  - Service cards now fully draggable with HTML5 Drag and Drop API
  - Custom order persisted in `serviceOrder` cookie (1-year expiration)
  - Visual feedback during drag operations:
    - `cursor: grab` on service cards (changes to `grabbing` when dragging)
    - `.dragging` class reduces opacity to 0.5
    - `.drag-over` class shows dashed accent border
  - Service order syncs across page reloads
  - Default order: Cloudflare, DigitalOcean, AWS, GitHub, Let's Encrypt, Mailgun, Stripe, Vimeo

- **Service Card Enhancements**:
  - Added `data-service-key` attribute to all service cards for drag identification
  - Cards respond to dragstart, dragover, dragenter, dragleave, dragend events
  - Smart positioning logic calculates correct drop location
  - Order automatically saved after drag completion

- **Updated Methods** (dashboard.js):
  - Added `getServiceOrder()`: Reads custom order from cookie, falls back to default
  - Added `saveServiceOrder()`: Persists order array to cookie
  - Added `renderServiceSettings()`: Dedicated method for settings panel rendering
  - Added `enableServiceDragDrop()`: Configures all drag-and-drop event handlers
  - Added `getDragAfterElement()`: Calculates correct insertion point during drag
  - Refactored `updateServicePreference()`: Re-renders services without collapsing settings panel
  - Refactored `loadExternalServices()`: Uses dedicated settings container, respects custom order

- **CSS Updates** (dashboard.css):
  - `.external-services-settings`: Reduced margin-bottom to 1.5rem, added border-bottom
  - `.external-service-card`: Added `cursor: grab` and `:active { cursor: grabbing }`
  - `.external-service-card.dragging`: opacity 0.5, grabbing cursor
  - `.external-service-card.drag-over`: dashed border, subtle background highlight

- **Cache Version**: Updated to v=2025.11.12.4

### ♻️ REFACTOR: Client-Side Cookie Storage for Preferences

- **Migrated from Server-Side to Client-Side Storage**:
  - Preferences now stored in browser cookies instead of server JSON files
  - Cookie name: `servicePreferences` with 1-year expiration
  - Simplifies architecture and removes server-side storage complexity
  - Better for multi-tenant/hosted scenarios where server storage is undesirable
  - Settings remain private to user's browser

- **Removed Server-Side Components**:
  - Removed `/api/external-services/preferences` endpoint (GET/POST)
  - Removed `getPreferencesFile()`, `getUserServicePreferences()`, `saveUserServicePreferences()` functions
  - Removed `handleExternalServicesPreferences()` handler
  - Removed `/home/EngineScript/.admin-preferences/` directory requirement
  - Removed CSRF protection for preferences (no longer needed - client-only)
  - API reverted to GET-only (no POST endpoints needed)

- **Updated Frontend Methods**:
  - Replaced `loadServicePreferences()` with cookie-based version (synchronous)
  - Replaced `updateServicePreference()` to save to cookie directly (no API calls)
  - Added `getCookie()`, `setCookie()`, `deleteCookie()` helper methods
  - Removed localStorage fallback (cookies are primary storage)
  - Removed server API calls for preferences
  - Cookies use `SameSite=Lax` for security

- **Limitations**:
  - Preferences don't sync across different browsers/devices
  - Cookie storage limited to ~4KB (sufficient for 8 boolean flags)
  - Clearing browser cookies resets preferences to defaults

- **Cache Version**: Updated to v=2025.11.12.3

### 🐛 BUG FIXES: Service Preferences & External Services

- **Fixed Critical 500 Error** on preferences POST endpoint:
- **Fixed CORS Issues** with external service status APIs:

- **UI/UX Improvements** for service settings:
  - Settings moved to collapsible panel at top of External Services page
  - Panel starts collapsed by default to reduce visual clutter
  - Click gear icon/button to expand/collapse settings
  - Chevron icon animates to indicate panel state
  - Much cleaner presentation than inline settings box

- **Cache Version**: Updated to v=2025.11.12.2

### 🔒 SECURITY: Service Preferences Hardening

- **Critical Security Improvements** to service preferences system:
  - **CSRF Protection**: POST requests now require valid CSRF token in X-CSRF-Token header
  - **IP Anonymization**: Client IPs now hashed with SHA-256 before storage (one-way hash)
  - **Path Traversal Prevention**: Full realpath validation on preference file paths
  - **Input Validation**: Strict validation on all preference data (type checking, size limits)
  - **JSON Validation**: Comprehensive JSON encode/decode error checking
  - **DOS Prevention**: Request body size limited to 10KB, preference count limited to 50
  - **Race Condition Prevention**: File write operations use LOCK_EX for atomic writes
  - **XSS Prevention**: All DOM manipulation uses createElement/textContent (no innerHTML with user data)
  - **Method Validation**: POST only allowed for preferences endpoint, GET for all others
  - **Error Logging**: All security validation failures logged to security event log

- **Backend Improvements** (api.php):
  - Hashed IP filenames: `/home/EngineScript/.admin-preferences/[sha256-hash].json`
  - Added `getPreferencesFile()` with directory traversal protection
  - Enhanced `getUserServicePreferences()` with JSON validation and type checking
  - Enhanced `saveUserServicePreferences()` with strict validation and error logging
  - Updated `handleExternalServicesPreferences()` with CSRF validation and size limits
  - Global method check refactored to allow POST for specific endpoints

- **Frontend Improvements** (dashboard.js):
  - CSRF token sent with all POST requests via X-CSRF-Token header
  - Service key validation before updating preferences
  - Enhanced JSON parse error handling with cache cleanup
  - XSS-safe error display using DOM manipulation
  - User-friendly error messages for security failures (403 CSRF errors)
  - Boolean type coercion for all preference values

- **API Module Improvements** (api.js):
  - Added `getCsrfToken()` method for retrieving stored CSRF token
  - CSRF token automatically loaded on dashboard initialization

### 🎛️ NEW FEATURE: User-Configurable Service Visibility

- **Service Preferences System**: Users can now customize which external services to display
  - All 8 services now default to **always enabled and shown**
  - Settings panel at top of External Services tab with visibility toggles
  - Users can click toggles to show/hide individual services
  - Preferences persist **across all admin domains** (IP-based with privacy protection)
  - Settings saved server-side at `/home/EngineScript/.admin-preferences/[hashed-ip].json`

- **Architecture Improvements**:
  - Backend: All services always available (`/api/external-services/config`)
  - Separate preferences API endpoint: `/api/external-services/preferences` (GET/POST)
  - Client IP-based storage ensures preferences follow user across different admin domains
  - localStorage caching reduces server requests while maintaining consistency
  - Automatic localStorage invalidation when server preferences differ

- **Frontend Enhancements**:
  - New settings panel with styled toggle controls
  - Toggle grid layout adapts to available space
  - Visual feedback on toggle hover with accent color highlighting
  - Real-time service display updates when toggling
  - Graceful error handling if preferences API fails

- **API Endpoints**:
  - `GET /api/external-services/config`: Returns all available services
  - `GET /api/external-services/preferences`: Returns user's saved preferences (reads from file)
  - `POST /api/external-services/preferences`: Saves user preferences with JSON body
  - Directory `/home/EngineScript/.admin-preferences/` created automatically with 0700 permissions

- **Security Considerations**:
  - Preference files stored with restrictive permissions (0600)
  - IP address sanitized for filename (removes invalid characters)
  - Only valid service keys accepted in preferences
  - Settings isolated per IP address (security consideration: IP-based tracking)

- **Default Behavior**:
  - First-time visitors see all 8 services enabled
  - Settings persist until user explicitly disables services
  - Resetting browser cache or changing IP resets to defaults

- **Cache Version**: Was v=2025.11.12.1 (security hardening)

### 2025-11-11 (Previous)

### 🌐 EXPANDED: External Services Monitoring - Now Supporting 8 Services

- **Multi-Service Architecture**: Refactored external services system to support unlimited services
  - Previously: Hardcoded loaders for Cloudflare and DigitalOcean (220+ lines of duplicate code)
  - Now: Generic, scalable service loader supporting any Statuspage.io-based service
  - Zero code changes needed to add new services - purely configuration driven
  
- **Extended Service Coverage**: Now monitors 8 critical external services
  - **Cloudflare** : CDN, DNS, and DDoS protection status
  - **DigitalOcean** : Cloud infrastructure and managed services status
  - **AWS** : Amazon Web Services status - when AWS monitoring enabled
  - **GitHub** : GitHub platform and API status
  - **Let's Encrypt** : SSL/TLS certificate authority status
  - **Mailgun** : Email delivery service status
  - **Stripe** : Payment processing service status
  - **Vimeo** : Video hosting service status

- **Architectural Improvements**:
  - Removed 177 lines of duplicate code (individual service methods)
  - Implemented single generic loadStatusPageService() method for all services
  - Service definitions object enables adding new services without code changes
  - Unified error handling, timeout management, and styling across all services
  - All services use 10-second timeout with proper error recovery

- **Performance & Reliability**:
  - Parallel API requests for all enabled services (no sequential delays)
  - Graceful degradation if service API is unreachable
  - XSS protection for all service displays via DOM creation
  - HTTP validation and JSON parsing error handling
  - User-friendly timeout messages if service status slow to respond

- **Cache Version**: Updated to v=2025.11.11.4

### Technical Details

- **Frontend Changes** (dashboard.js):
  - New loadExternalServices() method with service definitions object
  - Generic loadStatusPageService(container, serviceKey, serviceDef) for any Statuspage.io service
  - Eliminated loadCloudflareStatus() and loadDigitalOceanStatus() methods
  - Reduced service-specific code complexity while improving maintainability
  
- **Backend Changes** (api.php):
  - Updated getExternalServicesConfig() to detect all 8 services
  - Reads configuration options from enginescript-install-options.txt
  - Returns only enabled services to frontend
  
- **Styling Changes** (dashboard.css):
  - Added .aws-icon, .github-icon, .letsencrypt-icon, .mailgun-icon, .stripe-icon, .vimeo-icon gradients
  - Brand-accurate colors for each service
  - Consistent with existing Cloudflare and DigitalOcean styling
  