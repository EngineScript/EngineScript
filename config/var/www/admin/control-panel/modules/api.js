// EngineScript Admin Dashboard - API Module
// Handles all API communication with the backend

export class DashboardAPI {
  constructor() {
    this.csrfToken = null;
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

  isOperaMini() {
    return (
      Object.prototype.toString.call(window.operamini) === "[object OperaMini]"
    );
  }

  async getApiData(endpoint, fallback) {
    try {
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return fallback;
      }

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

      const data = await response.json();

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

      const response = await fetch("/services/status");
      const data = await response.json();

      return data[service] || { online: false, version: "Unknown" };
    } catch (error) {
      console.error(`Failed to get service status for ${service}:`, error);
      return { online: false, version: "Error" };
    }
  }
}
