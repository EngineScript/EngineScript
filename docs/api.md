# EngineScript Control Panel API Reference

API documentation for the EngineScript admin control panel. All endpoints are served from `/api/` on the control panel host.

## Table of Contents

- [Authentication & Security](#authentication--security)
- [Rate Limiting](#rate-limiting)
- [Caching](#caching)
- [Endpoints](#endpoints)
  - [CSRF Token](#csrf-token)
  - [System Info](#system-info)
  - [Service Status](#service-status)
  - [Sites](#sites)
  - [Sites Count](#sites-count)
  - [File Manager Status](#file-manager-status)
  - [Uptime Status](#uptime-status)
  - [Uptime Monitors](#uptime-monitors)
  - [Cache Clear](#cache-clear)
  - [Cache Status](#cache-status)
  - [Batch Requests](#batch-requests)
- [Error Responses](#error-responses)

---

## Authentication & Security

All API requests require an active PHP session (session-based authentication). Requests without a valid session receive a `403 Forbidden` response.

**CSRF Protection**: State-changing methods (`POST`, `PUT`, `DELETE`, `PATCH`) require a valid CSRF token sent via:

- `X-CSRF-Token` request header, **or**
- `_csrf_token` parameter in the request body

Obtain a token from the [`GET /csrf-token`](#csrf-token) endpoint. Token validation uses timing-safe comparison (`hash_equals`).

**CORS**: Same-origin only. Requests are restricted to the server's `HTTP_HOST`, `localhost`, and `127.0.0.1`.

**Security Headers**: All responses include `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, and a restrictive Content Security Policy.

---

## Rate Limiting

- **Limit**: 100 requests per minute per IP address
- **Tracking**: Session-based with SHA-256 hashed IP
- **Exceeded**: Returns `429 Too Many Requests`

---

## Caching

Responses are cached using a file-based cache at `/var/cache/enginescript/api/`. Cache TTLs vary per endpoint (noted below). Cached responses include a `X-Cache: HIT` header.

---

## Endpoints

### CSRF Token

Retrieve a CSRF token for use with state-changing requests.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/csrf-token` |
| **Cache TTL** | 30s |

**Response**

```json
{
  "csrf_token": "a1b2c3d4e5f6...64-char-hex-string",
  "token_name": "_csrf_token"
}
```

---

### System Info

Get server operating system, kernel, and network information.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/system/info` |
| **Cache TTL** | 60s |

**Response**

```json
{
  "os": "Ubuntu 24.04 LTS",
  "kernel": "6.8.0-40-generic",
  "network": "hostname (192.168.1.1)"
}
```

---

### Service Status

Get status of core LEMP stack services (Nginx, PHP-FPM, MariaDB, Redis).

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/services/status` |
| **Cache TTL** | 15s |

**Response**

```json
{
  "nginx": { "status": "online", "version": "1.27.4", "online": true },
  "php":   { "status": "online", "version": "8.4.1", "online": true },
  "mysql": { "status": "online", "version": "11.8.1", "online": true },
  "redis": { "status": "online", "version": "7.4.2", "online": true }
}
```

> **Note**: The `mysql` key reports MariaDB status. The `php` key dynamically discovers the active `php*-fpm` service.

---

### Sites

List all WordPress sites managed by EngineScript.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/sites` |
| **Cache TTL** | 120s |

**Response**

```json
[
  {
    "domain": "example.com",
    "status": "online",
    "wp_version": "6.7.1",
    "ssl_status": "Enabled"
  }
]
```

---

### Sites Count

Get the total number of managed WordPress sites.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/sites/count` |
| **Cache TTL** | 120s |

**Response**

```json
{
  "count": 3
}
```

> **Note**: `/sites/` (with trailing slash) is an alias for `/sites`.

---

### File Manager Status

Check availability and configuration of the Tiny File Manager integration.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/tools/filemanager/status` |
| **Cache TTL** | 300s |

**Response**

```json
{
  "available": true,
  "config_exists": true,
  "writable_dirs": {
    "/var/www": true,
    "/tmp": true
  },
  "url": "/tinyfilemanager/tinyfilemanager.php",
  "version": "2.5.3"
}
```

---

### Uptime Status

Get an aggregate overview of UptimeRobot monitor status.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/monitoring/uptime` |
| **Cache TTL** | 60s |

**Response** (configured)

```json
{
  "enabled": true,
  "overall_status": "healthy",
  "total_monitors": 5,
  "up": 4,
  "down": 1,
  "paused": 0
}
```

`overall_status` values: `healthy`, `critical`, `partial`, `unknown`

**Response** (not configured)

```json
{
  "enabled": false,
  "reason": "UptimeRobot API not configured"
}
```

---

### Uptime Monitors

Get detailed information for each individual UptimeRobot monitor.

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/monitoring/uptime/monitors` |
| **Cache TTL** | 60s |

**Response**

```json
{
  "enabled": true,
  "total": 5,
  "monitors": [
    {
      "id": 12345,
      "name": "example.com",
      "url": "https://example.com",
      "status": 2,
      "status_text": "Up",
      "uptime_day": 99.99,
      "uptime_week": 99.95,
      "uptime_month": 99.90,
      "last_check": 1709300000
    }
  ]
}
```

Monitor `status` codes: `0` Paused, `1` Not checked yet, `2` Up, `8` Seems down, `9` Down

---

### Cache Clear

Clear one or more server-side caches. Requires CSRF token.

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/cache/clear` |
| **Cache TTL** | None |

**Query Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | Comma-separated cache types: `redis`, `fastcgi`, `opcache` |

**Response**

```json
{
  "success": true,
  "cleared": ["redis", "fastcgi"],
  "results": {
    "redis": { "success": true, "message": "Redis cache cleared successfully" },
    "fastcgi": { "success": true, "message": "FastCGI cache cleared successfully" }
  }
}
```

If invalid types are included, a `warnings` field is added:

```json
{
  "warnings": {
    "invalid_types": ["foo"],
    "message": "Some requested cache types were invalid and ignored"
  }
}
```

**Errors**: `400` if `type` is empty or all types invalid. `405` if not POST.

---

### Cache Status

Get the current status of all cache systems (Redis, FastCGI, OPcache).

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/cache/status` |
| **Cache TTL** | 30s |

**Response**

```json
{
  "redis": { ... },
  "fastcgi": { ... },
  "opcache": { ... }
}
```

---

### Batch Requests

Execute multiple API calls in a single request. Requires CSRF token.

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/batch` |
| **Cache TTL** | None |

**Request Body** (JSON)

```json
{
  "requests": ["/system/info", "/services/status", "/sites"]
}
```

- Maximum 10 requests per batch
- **Allowed endpoints**: `/system/info`, `/services/status`, `/sites`, `/sites/count`, `/tools/filemanager/status`, `/monitoring/uptime`, `/monitoring/uptime/monitors`

**Response**

```json
{
  "results": {
    "/system/info": { "os": "Ubuntu 24.04 LTS", "kernel": "...", "network": "..." },
    "/services/status": { "nginx": { ... }, "php": { ... } }
  },
  "errors": {
    "/bad/endpoint": "Endpoint not allowed in batch requests"
  },
  "cached_count": 1
}
```

**Errors**: `400` if body invalid, missing `requests` array, or batch size exceeds 10. `405` if not POST.

---

## Error Responses

All errors follow a consistent JSON structure:

```json
{
  "error": "Error message description"
}
```

| Status Code | Description |
|---|---|
| `400` | Bad Request — missing or invalid parameters |
| `403` | Forbidden — invalid session or CSRF token |
| `404` | Not Found — unknown endpoint |
| `405` | Method Not Allowed — wrong HTTP method |
| `429` | Too Many Requests — rate limit exceeded (100 req/min) |
| `500` | Internal Server Error — unexpected server failure |
| `502` | Bad Gateway — upstream service unreachable |
