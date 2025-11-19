# Dashboard Version Management

## Overview

The EngineScript dashboard uses a **single source of truth** for version management to enable efficient cache-busting without manual scripts.

## How It Works

All dashboard resources (JS, CSS) are versioned using a query parameter (e.g., `?v=2025.11.19.02`). This version string comes from **one file**: `version.js`

### Version File

**Location**: `config/var/www/admin/control-panel/version.js`

```javascript
export const DASHBOARD_VERSION = '2025.11.19.02';
```

### Automatic Propagation

All files that need versioned imports use ES6 template literals:

**dashboard.js**:

```javascript
import { DASHBOARD_VERSION } from './version.js';
import { DashboardAPI } from `./modules/api.js?v=${DASHBOARD_VERSION}`;
```

**external-services.js**:

```javascript
import { DASHBOARD_VERSION } from '../version.js';
import { DashboardUtils } from `../modules/utils.js?v=${DASHBOARD_VERSION}`;
```

**index.html**:

```javascript
import { DASHBOARD_VERSION } from './version.js';
const script = document.createElement('script');
script.src = `dashboard.js?v=${DASHBOARD_VERSION}`;
```

## Updating the Version

### Step 1: Edit version.js

Open `config/var/www/admin/control-panel/version.js` and update the version string:

```javascript
export const DASHBOARD_VERSION = '2025.11.19.03'; // Increment build number
```

### Step 2: That's It

All files automatically use the new version. No scripts to run, no find-and-replace needed.

## Version Format

Format: `YYYY.MM.DD.NN`

- **YYYY**: Year (4 digits)
- **MM**: Month (2 digits, zero-padded)
- **DD**: Day (2 digits, zero-padded)
- **NN**: Build number (2 digits, increment for multiple releases per day)

Examples:

- `2025.11.19.01` - First build on November 19, 2025
- `2025.11.19.02` - Second build on November 19, 2025
- `2025.12.01.01` - First build on December 1, 2025

## Files Using Version Management

### Automatically Updated

✅ `dashboard.js` - Main dashboard module imports
✅ `external-services.js` - External services module imports
✅ `index.html` - CSS and script tags
✅ Version display footer

### Manual (External Dependencies)

❌ CDN resources (Chart.js, Font Awesome) - Updated via template variables

## Benefits

1. **Single Update Point**: Change version in one place
2. **No Bash Scripts**: Pure JavaScript/HTML solution
3. **Automatic Propagation**: Template literals handle distribution
4. **Developer Friendly**: Clear, simple process
5. **Version Display**: Footer automatically shows current version
6. **Cache Control**: Forces browser to fetch new resources

## Migration Notes

Previous system required updating version strings in multiple locations. This system consolidates everything into `version.js`.

**Old Approach** (deprecated):

- Update 15+ hardcoded version strings
- Run bash script to update files
- Manual find-and-replace operations

**New Approach** (current):

- Update 1 line in `version.js`
- All resources automatically updated
- Zero manual steps
