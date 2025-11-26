// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  constructor() {
    this.csrfToken = null;
    
    // Prevents duplicate API calls when multiple components request the same endpoint
    this.pendingRequests = new Map();
    
    // Service status cache with configurable TTL
    this.statusCache = new Map();
    this.defaultCacheTTL = 30000; // 30 seconds default cache
  }

  async loadCsrfToken() {
    try {
      const response = await fetch('/api/csrf-token', {
        method: 'GET',
        credentials: 'include'
      });
      if (response.ok) {
        const data = await response.json();
        this.csrfToken = data.csrf_token;
      } else {
        console.warn('Failed to load CSRF token');
      }
    } catch (error) {
      console.error('Error loading CSRF token:', error);
    }
  }

  getCsrfToken() {
    return this.csrfToken;
  }

  isOperaMini() {
    return (
      Object.prototype.toString.call(window.operamini) === "[object OperaMini]"
    );
  }

  /**
   * If a request to the same endpoint is already in-flight, return the existing promise
   * This prevents duplicate network requests when multiple components need the same data
   * 
   * @param {string} endpoint - The API endpoint
   * @param {Function} fetchFn - The function that performs the actual fetch
   * @returns {Promise} - The deduplicated promise
   */
  async deduplicateRequest(endpoint, fetchFn) {
    // Check if request is already in-flight
    if (this.pendingRequests.has(endpoint)) {
      return this.pendingRequests.get(endpoint);
    }

    // Create the promise and store it
    const requestPromise = fetchFn().finally(() => {
      // Remove from pending requests when complete (success or failure)
      this.pendingRequests.delete(endpoint);
    });

    this.pendingRequests.set(endpoint, requestPromise);
    return requestPromise;
  }

  async getApiData(endpoint, fallback) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return fallback;
      }

      // Use request deduplication for all GET requests
      const data = await this.deduplicateRequest(endpoint, async () => {
        const headers = {};
        if (this.csrfToken) {
          headers['X-CSRF-Token'] = this.csrfToken;
        }

        const response = await fetch(endpoint, {
          method: 'GET',
          headers: headers,
          credentials: 'include'
        });

        if (!response.ok) {
          throw new Error(`API ${endpoint} returned ${response.status}: ${response.statusText}`);
        }

        return response.json();
      });

      // Handle different response formats
      if (endpoint.includes("/system/memory") && data.usage) {
        return data.usage;
      }
      if (endpoint.includes("/system/disk") && data.usage) {
        return data.usage;
      }
      if (endpoint.includes("/system/cpu") && data.usage) {
        return data.usage;
      }
      if (endpoint.includes("/sites/count") && data.count !== undefined) {
        return data.count.toString();
      }

      return data;
    } catch (error) {
      console.error('API request failed:', error);
      return fallback;
    }
  }

  async postApiData(endpoint, data = {}) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { error: 'Fetch not supported' };
      }

      const headers = {
        'Content-Type': 'application/json'
      };
      if (this.csrfToken) {
        headers['X-CSRF-Token'] = this.csrfToken;
      }

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: headers,
        credentials: 'include',
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        throw new Error(`API ${endpoint} returned ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`Error posting to ${endpoint}:`, error);
      return { error: error.message };
    }
  }

  /**
   * Batch multiple API requests into a single call
   * Reduces network round-trips and improves performance
   * 
   * @param {string[]} endpoints - Array of API endpoints to fetch
   * @returns {Promise<Object>} - Object with results keyed by endpoint
   * 
   * @example
   * const data = await api.batchRequest(['/system/info', '/services/status']);
   * console.log(data.results['/system/info']);
   */
  async batchRequest(endpoints) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { error: 'Fetch not supported', results: {}, errors: {} };
      }

      if (!Array.isArray(endpoints) || endpoints.length === 0) {
        return { error: 'No endpoints provided', results: {}, errors: {} };
      }

      // Limit batch size client-side to match server limit
      const maxBatchSize = 10;
      if (endpoints.length > maxBatchSize) {
        console.warn(`Batch size ${endpoints.length} exceeds max ${maxBatchSize}, truncating`);
        endpoints = endpoints.slice(0, maxBatchSize);
      }

      const headers = {
        'Content-Type': 'application/json'
      };
      if (this.csrfToken) {
        headers['X-CSRF-Token'] = this.csrfToken;
      }

      const response = await fetch('/api/batch', {
        method: 'POST',
        headers: headers,
        credentials: 'include',
        body: JSON.stringify({ requests: endpoints })
      });

      if (!response.ok) {
        throw new Error(`Batch API returned ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Batch API request failed:', error);
      return { error: error.message, results: {}, errors: {} };
    }
  }

  async getServiceStatus(service) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { online: false, version: "Unavailable" };
      }

      const response = await fetch("/api/services/status");
      const data = await response.json();

      return data[service] || { online: false, version: "Unknown" };
    } catch (error) {
      console.error(`Failed to get service status for ${service}:`, error);
      return { online: false, version: "Error" };
    }
  }

  /**
   * Unified service/system status fetching function
   * Provides consistent interface for fetching status from any endpoint
   * with caching, deduplication, timeout handling, and uniform error responses
   * 
   * @param {string} endpoint - The API endpoint to fetch (e.g., '/api/services/status')
   * @param {Object} options - Configuration options
   * @param {number} options.cacheTTL - Cache time-to-live in ms (default: 30000)
   * @param {boolean} options.useCache - Whether to use caching (default: true)
   * @param {number} options.timeout - Request timeout in ms (default: 30000)
   * @param {*} options.fallback - Fallback value on error (default: null)
   * @param {string} options.method - HTTP method (default: 'GET')
   * @param {Object} options.body - Request body for POST requests
   * @param {AbortSignal} options.signal - External abort signal
   * @returns {Promise<Object>} - Consistent response: { success: boolean, data: any, error?: string, cached?: boolean }
   * 
   * @example
   * // Fetch all service statuses
   * const result = await api.fetchServiceStatus('/api/services/status');
   * if (result.success) {
   *   console.log(result.data.nginx.online);
   * }
   * 
   * @example
   * // Fetch with custom options
   * const result = await api.fetchServiceStatus('/api/system/info', {
   *   cacheTTL: 60000,
   *   timeout: 10000,
   *   fallback: { os: 'Unknown' }
   * });
   */
  async fetchServiceStatus(endpoint, options = {}) {
    const {
      cacheTTL = this.defaultCacheTTL,
      useCache = true,
      timeout = 30000,
      fallback = null,
      method = 'GET',
      body = null,
      signal = null
    } = options;

    // Standardized response format
    const createResponse = (success, data, error = null, cached = false) => ({
      success,
      data,
      error,
      cached,
      timestamp: Date.now()
    });

    try {
      // Check for fetch support
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return createResponse(false, fallback, 'Fetch not supported');
      }

      // Check cache first (only for GET requests with caching enabled)
      if (useCache && method === 'GET') {
        const cached = this.getStatusCache(endpoint);
        if (cached !== null) {
          return createResponse(true, cached, null, true);
        }
      }

      // Use request deduplication for GET requests
      const fetchFn = async () => {
        // Create abort controller for timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);

        try {
          const headers = {};
          if (this.csrfToken) {
            headers['X-CSRF-Token'] = this.csrfToken;
          }
          if (body) {
            headers['Content-Type'] = 'application/json';
          }

          const fetchOptions = {
            method,
            headers,
            credentials: 'include',
            signal: signal || controller.signal
          };

          if (body && method !== 'GET') {
            fetchOptions.body = JSON.stringify(body);
          }

          const response = await fetch(endpoint, fetchOptions);
          clearTimeout(timeoutId);

          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
          }

          const data = await response.json();

          // Cache successful GET responses
          if (useCache && method === 'GET') {
            this.setStatusCache(endpoint, data, cacheTTL);
          }

          return data;
        } catch (error) {
          clearTimeout(timeoutId);
          throw error;
        }
      };

      // Deduplicate concurrent requests to same endpoint (GET only)
      let data;
      if (method === 'GET') {
        data = await this.deduplicateRequest(endpoint, fetchFn);
      } else {
        data = await fetchFn();
      }

      return createResponse(true, data);

    } catch (error) {
      // Handle specific error types
      let errorMessage = error.message || 'Unknown error';
      
      if (error.name === 'AbortError') {
        errorMessage = 'Request timed out';
      } else if (error.message?.includes('Failed to fetch')) {
        errorMessage = 'Network error - unable to connect';
      }

      console.error(`fetchServiceStatus(${endpoint}) failed:`, errorMessage);
      return createResponse(false, fallback, errorMessage);
    }
  }

  /**
   * Get cached status data
   * @param {string} key - Cache key (typically endpoint)
   * @returns {*} - Cached data or null if expired/missing
   */
  getStatusCache(key) {
    const cached = this.statusCache.get(key);
    if (!cached) return null;

    if (Date.now() - cached.timestamp > cached.ttl) {
      this.statusCache.delete(key);
      return null;
    }

    return cached.data;
  }

  /**
   * Set cached status data
   * @param {string} key - Cache key
   * @param {*} data - Data to cache
   * @param {number} ttl - Time-to-live in ms
   */
  setStatusCache(key, data, ttl) {
    // Limit cache size to prevent memory issues (LRU-style eviction)
    const maxCacheSize = 50;
    if (this.statusCache.size >= maxCacheSize) {
      const oldestKey = this.statusCache.keys().next().value;
      this.statusCache.delete(oldestKey);
    }

    this.statusCache.set(key, {
      data,
      timestamp: Date.now(),
      ttl
    });
  }

  /**
   * Clear status cache (all or specific key)
   * @param {string} [key] - Optional specific key to clear
   */
  clearStatusCache(key = null) {
    if (key) {
      this.statusCache.delete(key);
    } else {
      this.statusCache.clear();
    }
  }

  /**
   * Fetch multiple service statuses in a single call
   * Uses batch API if available, falls back to parallel requests
   * 
   * @param {string[]} endpoints - Array of endpoints to fetch
   * @param {Object} options - Options passed to fetchServiceStatus
   * @returns {Promise<Object>} - Object with results keyed by endpoint
   */
  async fetchMultipleStatuses(endpoints, options = {}) {
    if (!Array.isArray(endpoints) || endpoints.length === 0) {
      return { results: {}, errors: {} };
    }

    const results = {};
    const errors = {};

    // Try batch API first if all endpoints are internal
    const allInternal = endpoints.every(e => e.startsWith('/api/'));
    if (allInternal && endpoints.length > 1) {
      try {
        const batchResult = await this.batchRequest(endpoints);
        if (!batchResult.error) {
          // Convert batch results to fetchServiceStatus format
          Object.entries(batchResult.results || {}).forEach(([endpoint, data]) => {
            results[endpoint] = { success: true, data, cached: false, timestamp: Date.now() };
          });
          Object.entries(batchResult.errors || {}).forEach(([endpoint, error]) => {
            errors[endpoint] = error;
            results[endpoint] = { success: false, data: null, error, cached: false, timestamp: Date.now() };
          });
          return { results, errors };
        }
      } catch (batchError) {
        console.warn('Batch request failed, falling back to parallel requests:', batchError);
      }
    }

    // Fallback: parallel individual requests
    const promises = endpoints.map(async (endpoint) => {
      const result = await this.fetchServiceStatus(endpoint, options);
      results[endpoint] = result;
      if (!result.success) {
        errors[endpoint] = result.error;
      }
    });

    await Promise.all(promises);
    return { results, errors };
  }
}
