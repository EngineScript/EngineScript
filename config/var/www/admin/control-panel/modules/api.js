// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  constructor() {
    this.csrfToken = null;
    
    // Prevents duplicate API calls when multiple components request the same endpoint
    this.pendingRequests = new Map();
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
}
