# EngineScript Control Panel API Reference

API documentation for the EngineScript admin control panel. All endpoints are served from `/api/` on the control panel host; `/api/system/info` and `/api.php?endpoint=system/info` reach the same endpoint.

## Table of Contents

- [Authentication & Security](#authentication--security)
- [Rate Limiting](#rate-limiting)
- [Responses and Caching](#responses-and-caching)
- [Endpoints](#endpoints)
  - [CSRF Token](#csrf-token)
  - [System Info](#system-info)
  - [Service Status](#service-status)
  - [Sites](#sites)
  - [File Manager Status](#file-manager-status)
  - [Uptime Status](#uptime-status)
  - [Uptime Monitors](#uptime-monitors)
  - [Cache Clear](#cache-clear)
  - [Cache Status](#cache-status)
- [Error Responses](#error-responses)

---

## Authentication & Security

**Authentication**: Nginx protects the whole control panel with HTTP basic authentication (`/etc/nginx/restricted-access/.htpasswd`). A request without valid credentials gets nginx's `401` before it reaches PHP.

**Session**: The API keeps a PHP session in the `__Host-esp_session` cookie (`Secure`, `HttpOnly`, `SameSite=Strict`). It holds the CSRF token and the rate-limit counter. A request without a session gets a new one; it is not refused.

**CSRF Protection**: `POST` requests (and any method other than `GET`, `HEAD`, and `OPTIONS`) need the session's CSRF token, sent as:

- the `X-CSRF-Token` request header, **or**
- a `_csrf_token` field in a form body or a JSON body.

Obtain the token from [`GET /csrf-token`](#csrf-token). It is compared in constant time (`hash_equals`). A missing or wrong token gets `403`. `GET` requests need no token.

**CORS**: None. The API sends no `Access-Control-*` headers: the dashboard calls it from its own origin, and browsers refuse cross-origin reads.

**Methods**: Every `GET` endpoint also answers `HEAD`. Any other method, `OPTIONS` included, gets `405` with an `Allow` header naming the methods the endpoint accepts.

**Endpoint names**: A path with characters other than letters, digits, `/`, `_`, and `-`, or longer than 100 characters, gets `400`; it is refused, never cleaned up.

**Security Headers**: The API sends `Content-Type: application/json; charset=UTF-8`, `Cache-Control: no-store`, and `Content-Security-Policy: default-src 'none'; frame-ancestors 'none';`. The admin site's nginx configuration adds `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Referrer-Policy: strict-origin-when-cross-origin` to every response, and leaves the API's `Cache-Control` as it is.

---

## Rate Limiting

- **Limit**: 100 requests per minute, counted in the session for the client's address (stored as a SHA-256 hash)
- **Exceeded**: `429` with `{"error": "Rate limit exceeded"}` until the minute is over

---

## Responses and Caching

Every response is JSON with `Cache-Control: no-store`: browsers and proxies keep no copy.

Strings are sent as they are, not HTML-escaped: a monitor named `Pete's Shop & Café` arrives as exactly that. Insert values into a page as text (the dashboard uses `textContent`). Bytes that are not valid UTF-8 arrive as `U+FFFD`.

The server caches one thing: UptimeRobot's monitor list, shared by both uptime endpoints for 60 seconds in `/var/cache/enginescript/api/`. Those two endpoints send `X-Cache: HIT` or `X-Cache: MISS`. Every other endpoint reads its data fresh on each request.

---

## Endpoints

### CSRF Token

Retrieve the session's CSRF token for `POST` requests.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/csrf-token` |

#### CSRF Token Response

```json
{
  "csrf_token": "a1b2c3d4e5f6...64-char-hex-string",
  "token_name": "_csrf_token"
}
```

`token_name` is the body field name the token may be sent in.

---

### System Info

Get the server's operating system, kernel, and network information.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/system/info` |

#### System Info Response

```json
{
  "os": "Ubuntu 24.04.3 LTS",
  "kernel": "6.8.0-40-generic",
  "network": "hostname (192.168.1.1)"
}
```

`os` is `PRETTY_NAME` from `/etc/os-release`, or `Unknown Linux Distribution`. `kernel` is `Unknown` when `uname -r` gives no version. In `network`, the host name or the address is `Unknown` when it cannot be read; the address is the one the server uses for outgoing traffic.

---

### Service Status

Get the state and version of Nginx, PHP-FPM, MariaDB, and Redis.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/services/status` |

#### Service Status Response

```json
{
  "nginx": { "version": "1.28.0", "online": true },
  "php":   { "version": "8.5.1", "online": true },
  "mysql": { "version": "11.8.5", "online": true },
  "redis": { "version": "8.2.3", "online": false }
}
```

`online` is `true` when `systemctl is-active` reports the unit active (`nginx.service`, `mariadb.service`, `redis-server.service`). `php` is the PHP-FPM process answering this request, so it is always online, with its own version. The `mysql` key reports MariaDB. `version` is `Unknown` when the version command gives none, and `Error` (with `online: false`) when the check itself fails.

---

### Sites

List the WordPress sites in Nginx's `/etc/nginx/sites-enabled`.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/sites` |

#### Sites Response

```json
[
  {
    "domain": "example.com",
    "wp_version": "6.8.3",
    "ssl_status": "Enabled"
  }
]
```

A site is listed when its configuration mentions WordPress. `domain` is the first `server_name`. `wp_version` comes from the site's `wp-includes/version.php`, or is `Unknown`. `ssl_status` is `Enabled` when the configuration names an `ssl_certificate`, otherwise `Unknown`. A configuration file that resolves outside `sites-enabled`, or a `version.php` that resolves outside the site's root, is not read.

---

### File Manager Status

Check the Tiny File Manager integration.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/tools/filemanager/status` |

#### File Manager Status Response

```json
{
  "available": true,
  "config_exists": true,
  "url": "/tinyfilemanager/tinyfilemanager.php",
  "version": "2.6"
}
```

`version` is `TINYFILEMANAGER_VER` from EngineScript's variables file, or `Unknown`.

---

### Uptime Status

Get a summary of the UptimeRobot account's monitors.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/monitoring/uptime` |
| **Server cache** | 60s, shared with Uptime Monitors |

#### Response: Configured

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

`overall_status` values: `critical` (a monitor is down or seems down), `healthy` (every active monitor is up; paused and not yet checked monitors are left out), `partial` (some up, others in an unknown state), `unknown` (no active monitors). `paused` counts paused and not yet checked monitors.

#### Response: Not Configured

```json
{
  "enabled": false,
  "reason": "UptimeRobot API not configured"
}
```

The API key is read from `api_key` in `/etc/enginescript/uptimerobot.conf`.

---

### Uptime Monitors

Get each UptimeRobot monitor.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/monitoring/uptime/monitors` |
| **Server cache** | 60s, shared with Uptime Status |

#### Uptime Monitors Response

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
      "uptime_day": 99.99
    }
  ]
}
```

Monitor `status` codes: `0` Paused, `1` Not checked yet, `2` Up, `8` Seems down, `9` Down, `-1` Unknown

`uptime_day` is the monitor's uptime over the last 24 hours, in percent, from UptimeRobot's per-monitor statistics. It is read for accounts with up to 8 monitors (one request each, so that with the list a refresh stays within UptimeRobot's free-plan limit of 10 requests a minute); above 8 monitors, or when a read fails, it is `null`.

When not configured, the answer is as for Uptime Status, with `"monitors": []`.

Both uptime endpoints answer from one read of UptimeRobot's API v3 (all pages of the monitor list, then the statistics). When UptimeRobot cannot be read, both answer `200` with `"enabled": true` and an `error` message (for example after UptimeRobot's limit of 10 requests a minute: `"UptimeRobot request limit reached; try again later"`); the monitors endpoint then also returns `"monitors": []`. A failure is cached for the minute like a result.

---

### Cache Clear

Clear one or more server caches. Requires the CSRF token.

| | |
| --- | --- |
| **Method** | `POST` |
| **Path** | `/cache/clear` |

#### Request Data

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | string | Yes* | Comma-separated cache types: `redis`, `fastcgi`, `opcache` |
| `types` | array | Yes* | JSON array of cache types: `["redis", "fastcgi"]` |

`type` may be sent as a query parameter or a JSON body field; `types` as a JSON body field. One of them is required.

#### Cache Clear Response

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

`success` is `false` when any requested cache failed to clear; each entry in `results` says which. `redis` runs `FLUSHALL`; `fastcgi` deletes the files under Nginx's cache directory, `/var/cache/nginx` (a missing directory counts as cleared); `opcache` resets PHP-FPM's OPcache.

If unknown types are included, they are ignored and a `warnings` field is added:

```json
{
  "warnings": {
    "invalid_types": ["foo"],
    "message": "Some requested cache types were invalid and ignored"
  }
}
```

**Errors**: `400` if no type is given or none is valid; `403` without a valid CSRF token; `405` for any method but `POST`.

---

### Cache Status

Get the current state of Redis, the FastCGI cache, and OPcache.

| | |
| --- | --- |
| **Method** | `GET`, `HEAD` |
| **Path** | `/cache/status` |

#### Cache Status Response

```json
{
  "redis": {
    "available": true,
    "used_memory": 1031336,
    "used_memory_human": "1007.16K"
  },
  "fastcgi": {
    "available": true,
    "path": "/var/cache/nginx",
    "size": "12K"
  },
  "opcache": {
    "available": true,
    "enabled": true,
    "memory_usage": { "used_memory": 9482240, "free_memory": 124735488, "wasted_memory": 0 },
    "statistics": { "num_cached_scripts": 19, "hits": 152, "misses": 19 }
  }
}
```

A cache that cannot be read is reported as `{"available": false, "reason": "..."}`: `Unable to connect to Redis`, `FastCGI cache directory not found`, `OPcache extension not available`, or `Unable to get OPcache status`. The FastCGI `size` is as `du -sh` prints it, or `Unknown`.

---

## Error Responses

Errors are JSON:

```json
{
  "error": "Error message description"
}
```

| Status Code | Description |
| --- | --- |
| `400` | Bad Request — an invalid endpoint name, or missing or invalid parameters |
| `401` | Unauthorized — sent by nginx, without valid basic-authentication credentials |
| `403` | Forbidden — a `POST` without a valid CSRF token |
| `404` | Not Found — unknown endpoint |
| `405` | Method Not Allowed — wrong HTTP method; the `Allow` header names the right ones |
| `429` | Too Many Requests — more than 100 requests in a minute |
| `500` | Internal Server Error — an unexpected failure; details go to the server's log, not the response |
