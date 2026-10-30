// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  static API_PREFIX = "/api/";

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
      try {
        const response = await fetch("/api/csrf-token", {
          method: "GET",
          credentials: "include"
        });
        if (response.ok) {
          const data = await response.json();
          this.csrfToken = data.csrf_token || null;
        } else {
          console.warn("Failed to load CSRF token");
        }
      } catch (error) {
        console.error("Error loading CSRF token:", error);
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
      Object.prototype.toString.call(globalThis.operamini) === "[object OperaMini]"
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
      console.error("Invalid API endpoint:", endpoint);
      return fallback;
    }
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return fallback;
      }

      // Use request deduplication for all GET requests
      // GET requests change nothing, so they carry no CSRF token.
      return await this.deduplicateRequest(endpoint, async () => {
        const response = await fetch(endpoint, {
          method: "GET",
          credentials: "include"
        });

        if (!response.ok) {
          throw new Error(`API ${endpoint} returned ${response.status}: ${response.statusText}`);
        }

        return this.parseJsonResponse(response);
      });
    } catch (error) {
      console.error("API request failed:", error);
      return fallback;
    }
  }

  async postApiData(endpoint, data = {}) {
    // Validate endpoint is a relative API path to prevent SSRF
    if (!this.isValidEndpoint(endpoint)) {
      console.error("Invalid API endpoint:", endpoint);
      return { error: "Invalid endpoint" };
    }
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { error: "Fetch not supported" };
      }

      if (!this.csrfToken) {
        await this.loadCsrfToken();
      }

      const headers = {
        "Content-Type": "application/json"
      };
      if (this.csrfToken) {
        headers["X-CSRF-Token"] = this.csrfToken;
      }

      const response = await fetch(endpoint, {
        method: "POST",
        headers,
        credentials: "include",
        body: JSON.stringify(data)
      });

      const payload = await this.parseJsonResponse(response);
      if (!response.ok) {
        throw new Error(payload?.error || `API ${endpoint} returned ${response.status}: ${response.statusText}`);
      }

      return payload;
    } catch (error) {
      console.error(`Error posting to ${endpoint}:`, error);
      return { error: error.message };
    }
  }

  async parseJsonResponse(response) {
    try {
      return await response.json();
    } catch (error) {
      throw new Error(`Invalid JSON response: ${error.message}`, { cause: error });
    }
  }
}
