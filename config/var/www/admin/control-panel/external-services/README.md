# External Services Module

A standalone, modular external service status monitoring system. This module can be integrated into the EngineScript admin dashboard or used as the foundation for a standalone project.

## 📁 Module Structure

```plaintext
external-services/
├── external-services.js          # Main ES6 module class
├── external-services.css         # Complete styling
├── external-services-api.php     # Backend feed parsing & API
├── external-services.html        # Integration guide & documentation
└── README.md                     # This file
```

## 🚀 Quick Start

### Integration in Admin Dashboard

The module is already integrated into the EngineScript admin dashboard:

```html
<!-- In index.html -->
<link rel="stylesheet" href="external-services/external-services.css?v=2.25.2026">
<script type="module" src="external-services/external-services.js?v=2.25.2026"></script>
```

```javascript
// In dashboard.js
import { ExternalServicesManager } from './external-services/external-services.js?v=2.25.2026';

class EngineScriptDashboard {
  constructor() {
    this.externalServices = new ExternalServicesManager(
      'external-services-grid',      // Container ID for service cards
      'external-services-settings'   // Container ID for settings panel
    );
  }
  
  loadPageData(pageName) {
    if (pageName === 'external-services') {
      this.externalServices.init();
    }
  }
}
```

### Required DOM Structure

```html
<div id="external-services-page" class="page-content">
  <div class="page-header">
    <h2>External Services Status</h2>
  </div>
  
  <!-- Settings panel container -->
  <div id="external-services-settings" class="external-services-settings"></div>
  
  <!-- Service cards container -->
  <div id="external-services-grid" class="external-services-grid"></div>
</div>
```

### Backend API Integration

The backend API file (`external-services-api.php`) should be integrated into your main API router:

```php
// In api.php
require_once 'external-services/external-services-api.php';

// Handle routes
if (strpos($requestPath, '/external-services/') === 0) {
    if ($requestPath === '/external-services/config') {
        handleExternalServicesConfig();
    } elseif ($requestPath === '/external-services/feed') {
        handleStatusFeed();
    }
}
```

## ✨ Features

- **60+ service integrations** across 9 categories
- **Three monitoring types:**
  - StatusPage.io JSON APIs (direct CORS requests)
  - RSS/Atom feeds (via backend proxy)
  - Static links (manual check services like AWS)

### User Experience

- **Immediate card display** with async status loading
- **Staggered requests** (60ms delay) to prevent timeout issues
- **Drag-and-drop reordering** with position swapping
- **Settings panel** with per-service toggle switches
- **Persistent preferences** via browser cookies

### Performance

- **5-minute client-side caching** for improved speed
- **30-second request timeouts** for reliability
- **Non-blocking async** - services load independently

### Security

- **Input sanitization** on all user data
- **XSS prevention** with strict whitelisting
- **Feed type validation** with hardcoded whitelist
- **CSRF protection** via token validation

## 📦 Dependencies

### Client-Side

- **Font Awesome** (icons)
- **Modern browser** with ES6 module support
- **Shared utilities** from `../modules/utils.js`

### Server-Side

- **PHP 8.0+** with SimpleXML extension
- **cURL or file_get_contents** for external requests
- **JSON encoding/decoding** functions

## 🎨 Customization

### Adding New Services

1. **Add service definition** in `external-services.js`:

```javascript
getServiceDefinitions() {
  return {
    // ... existing services
    myservice: {
      name: 'My Service',
      category: 'Developer Tools',
      api: 'https://status.myservice.com/api/v2/status.json',
      url: 'https://status.myservice.com/',
      icon: 'fa-code',
      color: 'myservice-icon',
      corsEnabled: true
    }
  };
}
```

1. **Add to backend whitelist** in `external-services-api.php`:

```php
$config = [
}
```

2. **Add icon styling** in `external-services.css`:

```css
.service-icon.myservice-icon {
    background: linear-gradient(135deg, #ff6b6b, #ee5a52);
}
```

3. **Add to backend whitelist** in `external-services-api.php`:

```php
$config = [
    // ... existing services
    'myservice' => true
];
```

4. **Add to default order** in `external-services.js`:

```javascript
getServiceOrder() {
  return [
    // ... existing services in alphabetical order
    'myservice'
  ];
}
```

### Styling Customization

All styles are contained in `external-services.css`. Key CSS custom properties:

```css
/* Override these in your main stylesheet */
:root {
  --card-bg: #1e1e2e;
  --card-hover: #262637;
  --border-color: rgba(255, 255, 255, 0.1);
  --success-color: #00d4aa;
  --warning-color: #ffbb00;
  --error-color: #ff4444;
}
```

## 🔧 Configuration

### Cache Duration

Change the cache expiry time in `external-services.js`:

```javascript
constructor(gridContainerId, settingsContainerId) {
  this.cacheExpiry = 300000; // 5 minutes default, change as needed
}
```

### Request Timeout

Adjust timeout in `updateFeedServiceStatus()` and `updateStatusPageServiceStatus()`:

```javascript
const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 seconds
```

### Stagger Delay

Modify the delay between service requests:

```javascript
const delay = serviceIndex * 60; // 60ms between requests, adjust as needed
```

## 📊 Service Categories

1. **Hosting & Infrastructure** (17 services)
2. **Developer Tools** (10 services)
3. **E-Commerce & Payments** (9 services)
4. **Email & Communication** (8 services)
5. **Media & Content** (6 services)
6. **Gaming** (1 service)
7. **AI & Machine Learning** (2 services)
8. **Advertising** (5 services)
9. **Security** (2 services)

## 🌐 Browser Compatibility

- **Chrome/Edge**: 88+ ✅
- **Firefox**: 78+ ✅
- **Safari**: 14+ ✅
- **Opera**: 74+ ✅

Requires ES6 module support and modern JavaScript features (async/await, template literals, arrow functions).

## 📝 License

Part of EngineScript - LEMP server automation toolkit.

## 🔗 Related Files

- Main dashboard integration: `../dashboard.js`
- Shared utilities: `../modules/utils.js`
- Shared state management: `../modules/state.js`
- Backend API router: `../api.php`

## 📧 Support

For issues or questions, refer to the main EngineScript documentation or CHANGELOG.md.

---

**Version**: 2025.11.14.01  
**Status**: Production Ready ✅
