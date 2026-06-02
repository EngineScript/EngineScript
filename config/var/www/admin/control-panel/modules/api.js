// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  static API_PREFIX = "/api/";
  static MAX_BATCH_SIZE = 10;

  constructor() {
    this.csrfToken = null;
    this.csrfTokenPromise = null;
    
    // Prevents duplicate API calls when multiple components request the same endpoint
    this.pendingRequests = new Map();
  }

  async loadCsrfToken() {
    if (this.csrfToken) {
      return this.csrfToken;
    }

    if (this.csrfTokenPromise) {
      return this.csrfTokenPromise;
    }

    this.csrfTokenPromise = (async () => {
      try { // codacy:ignore - Try/catch required for CSRF token loading
        const response = await fetch('/api/csrf-token', {
          method: 'GET',
          credentials: 'include'
        });
        if (response.ok) {
          const data = await response.json();
          this.csrfToken = data.csrf_token || null;
        } else {
          console.warn('Failed to load CSRF token');
        }
      } catch (error) {
        console.error('Error loading CSRF token:', error);
      } finally {
        this.csrfTokenPromise = null;
      }

      return this.csrfToken;
    })();

    return this.csrfTokenPromise;
  }

  getCsrfToken() {
    return this.csrfToken;
  }

  isValidEndpoint(endpoint) {
    return typeof endpoint === "string" && endpoint.startsWith(DashboardAPI.API_PREFIX);
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
   * @returns {Promise} The deduplicated promise
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
    // Validate endpoint is a relative API path to prevent SSRF
    if (!this.isValidEndpoint(endpoint)) {
      console.error('Invalid API endpoint:', endpoint);
      return fallback;
    }
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

        // codacy:ignore - SSRF mitigated: endpoint validated above to start with '/api/'
        const response = await fetch(endpoint, {
          method: 'GET',
          headers: headers,
          credentials: 'include'
        });

        if (!response.ok) {
          throw new Error(`API ${endpoint} returned ${response.status}: ${response.statusText}`);
        }

        return this.parseJsonResponse(response);
      });

      // Handle endpoint-specific response format differences.
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
    // Validate endpoint is a relative API path to prevent SSRF
    if (!this.isValidEndpoint(endpoint)) {
      console.error('Invalid API endpoint:', endpoint);
      return { error: 'Invalid endpoint' }; // codacy:ignore - Object literal return
    }
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { error: 'Fetch not supported' }; // codacy:ignore - Object literal return
      }

      if (!this.csrfToken) {
        await this.loadCsrfToken();
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

      const payload = await this.parseJsonResponse(response);
      if (!response.ok) {
        throw new Error(payload?.error || `API ${endpoint} returned ${response.status}: ${response.statusText}`);
      }

      return payload;
    } catch (error) {
      console.error(`Error posting to ${endpoint}:`, error);
      return { error: error.message }; // codacy:ignore - Object literal return
    }
  }

  /**
   * Batch multiple API requests into a single call
   * Reduces network round-trips and improves performance
   * 
   * @param {string[]} endpoints - Array of API endpoints to fetch. If more than
   *   the maximum batch size are provided, only the first `maxBatchSize`
   *   endpoints are sent in the request.
   * @returns {Promise<Object>} Object with results keyed by endpoint
   * 
   * @example
   * const data = await api.batchRequest(['/system/info', '/services/status']);
   * console.log(data.results['/system/info']);
   */
  async batchRequest(endpoints) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { error: 'Fetch not supported', results: {}, errors: {} }; // codacy:ignore - Object literal return
      }

      if (!this.csrfToken) {
        await this.loadCsrfToken();
      }

      if (!Array.isArray(endpoints) || endpoints.length === 0) {
        return { error: 'No endpoints provided', results: {}, errors: {} }; // codacy:ignore - Object literal return
      }

      // Limit batch size client-side to match server limit
      let limitedEndpoints = endpoints;
      if (endpoints.length > DashboardAPI.MAX_BATCH_SIZE) {
        console.warn(`Batch size ${endpoints.length} exceeds max ${DashboardAPI.MAX_BATCH_SIZE}, truncating`);
        limitedEndpoints = endpoints.slice(0, DashboardAPI.MAX_BATCH_SIZE);
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
        body: JSON.stringify({ requests: limitedEndpoints })
      });

      const payload = await this.parseJsonResponse(response);
      if (!response.ok) {
        throw new Error(payload?.error || `Batch API returned ${response.status}: ${response.statusText}`);
      }

      return payload;
    } catch (error) {
      console.error('Batch API request failed:', error);
      return { error: error.message, results: {}, errors: {} }; // codacy:ignore - Object literal return
    }
  }

  async parseJsonResponse(response) {
    try {
      return await response.json();
    } catch (error) {
      throw new Error(`Invalid JSON response: ${error.message}`);
    }
  }

}
