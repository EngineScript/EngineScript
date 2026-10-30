// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  static API_PREFIX = "/api/";

  // Longer than the server's own budget (20 seconds for commands and for UptimeRobot),
  // so the server answers first whenever it can.
  static REQUEST_TIMEOUT_MS = 30000;

  // The API's answer when the CSRF token does not belong to the session (api.php)
  static CSRF_ERROR = "Invalid or missing CSRF token";

  constructor() {
    this.csrfToken = null;
    this.csrfTokenPromise = null;

    // Prevents duplicate API calls when multiple components request the same endpoint
    this.pendingRequests = new Map();
  }

  /**
   * Load the session's CSRF token, once; with refresh, load it again (a new session has a new one).
   */
  async loadCsrfToken(refresh = false) {
    if (refresh) {
      this.csrfToken = null;
    }

    if (this.csrfToken) {
      return this.csrfToken;
    }

    if (this.csrfTokenPromise) {
      return this.csrfTokenPromise;
    }

    this.csrfTokenPromise = (async () => {
      try {
        const response = await this.request("/api/csrf-token", { method: "GET" });
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

  isValidEndpoint(endpoint) {
    return typeof endpoint === "string" && endpoint.startsWith(DashboardAPI.API_PREFIX);
  }

  /**
   * fetch() with the session cookie and a time limit. A request that runs out of time
   * rejects with an error that says so.
   *
   * @param {string} endpoint - The API endpoint
   * @param {RequestInit} options - fetch() options
   * @returns {Promise<Response>} The response
   */
  async request(endpoint, options) {
    const signal = AbortSignal.timeout(DashboardAPI.REQUEST_TIMEOUT_MS);
    try {
      return await fetch(endpoint, {
        ...options,
        credentials: "include",
        signal
      });
    } catch (error) {
      // Only the time limit aborts this signal. WebKit rejects with its own AbortError
      // rather than the signal's TimeoutError, so the signal is checked, not the error.
      if (signal.aborted) {
        throw new Error(`The server did not answer within ${DashboardAPI.REQUEST_TIMEOUT_MS / 1000} seconds`, { cause: error });
      }
      throw error;
    }
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

  /**
   * GET an API endpoint and return its JSON. Any failure (an invalid endpoint, a network
   * error, a timeout, an error status, or invalid JSON) rejects, with the API's own error
   * message when it sent one, so each page can show an error instead of empty data.
   *
   * @param {string} endpoint - The API endpoint
   * @returns {Promise<*>} The decoded JSON
   */
  async getApiData(endpoint) {
    // Validate endpoint is a relative API path to prevent SSRF
    if (!this.isValidEndpoint(endpoint)) {
      throw new Error(`Invalid API endpoint: ${endpoint}`);
    }

    // Use request deduplication for all GET requests
    // GET requests change nothing, so they carry no CSRF token.
    return this.deduplicateRequest(endpoint, async () => {
      const response = await this.request(endpoint, { method: "GET" });
      return this.readPayload(endpoint, response);
    });
  }

  async postApiData(endpoint, data = {}) {
    // Validate endpoint is a relative API path to prevent SSRF
    if (!this.isValidEndpoint(endpoint)) {
      console.error("Invalid API endpoint:", endpoint);
      return { error: "Invalid endpoint" };
    }
    try {
      let response = await this.post(endpoint, data);

      // The session ended (for example after the page sat idle) and its token with it: the
      // server refused the request before acting on it, so load the new session's token and
      // send it once more. Nothing else is retried, a network failure least of all.
      if (response.status === 403 && (await this.errorOf(response)) === DashboardAPI.CSRF_ERROR) {
        await this.loadCsrfToken(true);
        response = await this.post(endpoint, data);
      }

      return await this.readPayload(endpoint, response);
    } catch (error) {
      console.error(`Error posting to ${endpoint}:`, error);
      return { error: error.message };
    }
  }

  /**
   * Send one POST with the session's CSRF token, loading the token first if needed.
   */
  async post(endpoint, data) {
    if (!this.csrfToken) {
      await this.loadCsrfToken();
    }

    const headers = {
      "Content-Type": "application/json"
    };
    if (this.csrfToken) {
      headers["X-CSRF-Token"] = this.csrfToken;
    }

    return this.request(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(data)
    });
  }

  /**
   * The JSON of a successful response; for an error status, a rejection with the API's own
   * error message, or the status when the body is not the API's JSON (nginx's error pages).
   */
  async readPayload(endpoint, response) {
    if (!response.ok) {
      throw new Error((await this.errorOf(response)) || `API ${endpoint} returned ${response.status}: ${response.statusText}`);
    }

    return this.parseJsonResponse(response);
  }

  /**
   * The "error" field of an error response's JSON, or null. Reads a clone, so the body stays readable.
   */
  async errorOf(response) {
    try {
      const payload = await response.clone().json();
      return typeof payload?.error === "string" ? payload.error : null;
    } catch {
      return null;
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
