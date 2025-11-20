// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v=2025.11.12.16';
import { SERVICE_DEFINITIONS } from './services-config.js?v=2025.11.19.01';

export class ExternalServicesManager {
  constructor(containerSelector, settingsContainerSelector) {
    this.utils = new DashboardUtils();
    this.container = document.querySelector(containerSelector);
    this.settingsContainer = document.querySelector(settingsContainerSelector);
    
    // State management with cache (5-minute TTL)
    this.serviceCache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes in milliseconds
    this.initialized = false; // Track if services have been loaded (lazy loading)
  }

  /**
   * Initialize the external services manager (lazy loading)
   * Only loads when user navigates to external services page
   */
  async init() {
    if (!this.container || !this.settingsContainer) {
      console.error('External services container or settings container not found');
      return;
    }

    // Prevent duplicate initialization - only load once
    if (this.initialized) {
      console.log('External services already initialized, skipping reload...');
      return;
    }

    this.initialized = true;
    await this.loadExternalServices();
  }

  /**
   * Main method to load and display all external services
   */
  async loadExternalServices() {
    try {
      this.container.innerHTML = "";

      // Get service definitions first (always available)
      const serviceDefinitions = this.getServiceDefinitions();
      
      // Try to fetch from API, but fall back to definitions if it fails
      const services = await this.fetchAvailableServices();
      
      // Load preferences from cookie (client-side only)
      let preferences = this.loadServicePreferences() || {};
      let serviceOrder = this.getServiceOrder();

      // Render settings panel in dedicated container
      this.renderServiceSettings(this.settingsContainer, services, serviceDefinitions);

      // Get service keys in custom order
      let orderedServiceKeys = serviceOrder.filter(key => services[key]);
      // Add any new services not in the saved order
      Object.keys(services).forEach(key => {
        if (!orderedServiceKeys.includes(key)) {
          orderedServiceKeys.push(key);
        }
      });

      // Check if any services are enabled (must be explicitly set to true)
      const enabledServices = orderedServiceKeys.filter(key => {
        return serviceDefinitions[key] && preferences[key] === true;
      });

      // If no services are enabled, show empty state
      if (enabledServices.length === 0) {
        const emptyState = document.createElement("div");
        emptyState.className = "empty-state";
        emptyState.innerHTML = `
          <div class="empty-state-icon">
            <i class="fas fa-toggle-off"></i>
          </div>
          <h3>No Services Selected</h3>
          <p>Click the "Service Settings" button above to enable external service monitoring.</p>
        `;
        this.container.appendChild(emptyState);
        return;
      }

      // Group enabled services by category
      const servicesByCategory = {};
      for (const serviceKey of orderedServiceKeys) {
        if (serviceDefinitions[serviceKey] && preferences[serviceKey] === true) {
          const serviceDef = serviceDefinitions[serviceKey];
          const category = serviceDef.category || 'Other';
          
          if (!servicesByCategory[category]) {
            servicesByCategory[category] = [];
          }
          servicesByCategory[category].push({ key: serviceKey, def: serviceDef });
        }
      }

      // Render services grouped by category
      for (const category in servicesByCategory) {
        // Create category header
        const categoryHeader = document.createElement("div");
        categoryHeader.className = "service-category-header";
        categoryHeader.innerHTML = `<h3>${category}</h3>`;
        this.container.appendChild(categoryHeader);

        // Create category container
        const categoryContainer = document.createElement("div");
        categoryContainer.className = "service-category-grid";
        categoryContainer.dataset.category = category;

        // Display all cards immediately with loading state, then fetch statuses asynchronously
        for (const { key: serviceKey, def: serviceDef } of servicesByCategory[category]) {
          // Check if this is a static service (no API or feed)
          if (!serviceDef.useFeed && !serviceDef.corsEnabled && !serviceDef.api) {
            // Display static card immediately (e.g., AWS)
            this.displayStaticServiceCard(categoryContainer, serviceKey, serviceDef);
          } else {
            // Display card immediately with loading state
            this.displayServiceCardWithLoadingState(categoryContainer, serviceKey, serviceDef);
            
            // Fire all requests immediately in parallel - browser and server handle concurrency
            // Each request is fully independent and non-blocking with its own timeout
            if (serviceDef.useFeed) {
              this.updateFeedServiceStatus(serviceKey, serviceDef).catch(err => {
                console.error(`Failed to load ${serviceDef.name}:`, err);
              });
            } else if (serviceDef.corsEnabled && serviceDef.api) {
              this.updateStatusPageServiceStatus(serviceKey, serviceDef).catch(err => {
                console.error(`Failed to load ${serviceDef.name}:`, err);
              });
            }
          }
        }

        this.container.appendChild(categoryContainer);
      }
      
      // Enable drag and drop for service cards
      this.enableServiceDragDrop(this.container);
    } catch (error) {
      console.error('Failed to load external services:', error);
      this.container.innerHTML = "";
      const errorDiv = document.createElement("div");
      errorDiv.className = "error-state";
      errorDiv.innerHTML = `
        <div class="error-icon">
          <i class="fas fa-exclamation-circle"></i>
        </div>
        <h3>Error Loading External Services</h3>
        <p>Failed to fetch external service status. Please try again later.</p>
      `;
      this.container.appendChild(errorDiv);
    }
  }

  /**
   * Fetch available services from API
   */
  async fetchAvailableServices() {
    try {
      const response = await fetch("/api/external-services/config", { credentials: 'include' });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      let services = data.services || data;
      
      // If API failed or returned empty, use all services from definitions
      if (!services || Object.keys(services).length === 0) {
        const serviceDefinitions = this.getServiceDefinitions();
        services = {};
        Object.keys(serviceDefinitions).forEach(key => {
          services[key] = true;
        });
      }
      
      return services;
    } catch (error) {
      console.error('Failed to fetch services config:', error);
      // Fallback: return all services enabled
      const serviceDefinitions = this.getServiceDefinitions();
      const services = {};
      Object.keys(serviceDefinitions).forEach(key => {
        services[key] = true;
      });
      return services;
    }
  }

  /**
   * Get service definitions for all supported external services
   */
  getServiceDefinitions() {
    return SERVICE_DEFINITIONS;
  }

  /**
   * Render the service settings panel with toggles
   */
  renderServiceSettings(settingsContainer, services, serviceDefinitions) {
    settingsContainer.innerHTML = "";
    
    const settingsToggle = document.createElement("button");
    settingsToggle.className = "settings-toggle-btn";
    settingsToggle.setAttribute("aria-expanded", "false");
    settingsToggle.setAttribute("aria-controls", "settings-panel");
    settingsToggle.setAttribute("aria-label", "Toggle service settings panel");
    settingsToggle.innerHTML = `
      <i class="fas fa-cog" aria-hidden="true"></i>
      <span>Service Settings</span>
      <i class="fas fa-chevron-down toggle-icon" aria-hidden="true"></i>
    `;
    
    const settingsContent = document.createElement("div");
    settingsContent.className = "settings-content collapsed";
    settingsContent.id = "settings-panel";
    settingsContent.setAttribute("role", "region");
    settingsContent.setAttribute("aria-labelledby", "settings-toggle-label");
    
    const settingsHeader = document.createElement("div");
    settingsHeader.className = "settings-header";
    settingsHeader.innerHTML = `<p>Toggle services to show/hide on the dashboard. Drag service cards to reorder them. Click "Save Changes" to apply. Services are organized by category.</p>`;
    
    settingsContent.appendChild(settingsHeader);
    
    // Track pending changes
    const pendingChanges = {};
    
    settingsToggle.addEventListener("click", () => {
      const isCollapsed = settingsContent.classList.toggle("collapsed");
      const icon = settingsToggle.querySelector(".toggle-icon");
      icon.className = isCollapsed ? "fas fa-chevron-down toggle-icon" : "fas fa-chevron-up toggle-icon";
      settingsToggle.setAttribute("aria-expanded", isCollapsed ? "false" : "true");
    });
    
    settingsContainer.appendChild(settingsToggle);
    settingsContainer.appendChild(settingsContent);

    // Group services by category
    const categories = {};
    for (const [serviceKey] of Object.entries(services)) {
      if (serviceDefinitions[serviceKey]) {
        const category = serviceDefinitions[serviceKey].category || 'Other';
        if (!categories[category]) {
          categories[category] = [];
        }
        categories[category].push(serviceKey);
      }
    }

    // Render each category
    const categoryOrder = [
      'Hosting & Infrastructure',
      'Developer Tools',
      'E-Commerce & Payments',
      'Email Services',
      'Communication',
      'Media & Content',
      'Gaming',
      'AI & Machine Learning',
      'Advertising',
      'Security'
    ];

    for (const category of categoryOrder) {
      if (!categories[category]) continue;

      const categorySection = document.createElement("div");
      categorySection.className = "category-section";

      const categoryHeader = document.createElement("div");
      categoryHeader.className = "category-header";
      categoryHeader.innerHTML = `
        <span>${category}</span>
        <button class="category-toggle-btn" data-category="${category}">
          <span class="toggle-all-text">Toggle All</span>
          <i class="fas fa-toggle-on"></i>
        </button>
      `;

      categorySection.appendChild(categoryHeader);

      const servicesGrid = document.createElement("div");
      servicesGrid.className = "services-grid";

      const categoryCheckboxes = [];
      
      categories[category].forEach(serviceKey => {
        const serviceDef = serviceDefinitions[serviceKey];
        const isEnabled = services[serviceKey];
        
        const toggleLabel = document.createElement("label");
        toggleLabel.className = "service-toggle";
        
        const checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.checked = isEnabled;
        checkbox.dataset.service = serviceKey;
        checkbox.setAttribute("aria-label", `Toggle ${serviceDef.name} service visibility`);
        
        checkbox.addEventListener("change", () => {
          pendingChanges[serviceKey] = checkbox.checked;
        });
        
        const serviceName = document.createElement("span");
        serviceName.textContent = serviceDef.name;
        
        toggleLabel.appendChild(checkbox);
        toggleLabel.appendChild(serviceName);
        servicesGrid.appendChild(toggleLabel);
        
        categoryCheckboxes.push(checkbox);
      });

      // Add toggle all button functionality
      const toggleBtn = categoryHeader.querySelector(".category-toggle-btn");
      toggleBtn.addEventListener("click", () => {
        const allEnabled = categoryCheckboxes.every(cb => cb.checked);
        categoryCheckboxes.forEach(cb => {
          cb.checked = !allEnabled;
          cb.dispatchEvent(new Event('change'));
        });
      });

      categorySection.appendChild(servicesGrid);
      settingsContent.appendChild(categorySection);
    }

    // Save button
    const saveButton = document.createElement("button");
    saveButton.className = "save-settings-btn";
    saveButton.innerHTML = '<i class="fas fa-save" aria-hidden="true"></i> Save Changes';
    saveButton.disabled = true;
    saveButton.setAttribute("aria-label", "Save service settings changes");
    saveButton.setAttribute("aria-disabled", "true");
    
    saveButton.addEventListener("click", async () => {
      try {
        saveButton.disabled = true;
        saveButton.setAttribute("aria-disabled", "true");
        saveButton.innerHTML = '<i class="fas fa-spinner fa-spin" aria-hidden="true"></i> Saving...';
        saveButton.setAttribute("aria-label", "Saving service settings");
        
        const response = await fetch("/api/external-services/config", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(pendingChanges),
          credentials: 'include'
        });
        
        if (!response.ok) throw new Error("Failed to save");
        
        // Update local services object
        Object.assign(services, pendingChanges);
        Object.keys(pendingChanges).length = 0;
        
        saveButton.innerHTML = '<i class="fas fa-check" aria-hidden="true"></i> Saved!';
        saveButton.setAttribute("aria-label", "Service settings saved successfully");
        setTimeout(() => {
          saveButton.innerHTML = '<i class="fas fa-save" aria-hidden="true"></i> Save Changes';
          saveButton.setAttribute("aria-label", "Save service settings changes");
          saveButton.classList.remove('has-changes');
        }, 2000);
        
        // Reload services display
        await this.init();
      } catch (error) {
        console.error("Save error:", error);
        saveButton.innerHTML = '<i class="fas fa-times" aria-hidden="true"></i> Save Failed';
        saveButton.setAttribute("aria-label", "Failed to save service settings");
        saveButton.disabled = false;
        saveButton.setAttribute("aria-disabled", "false");
        setTimeout(() => {
          saveButton.innerHTML = '<i class="fas fa-save" aria-hidden="true"></i> Save Changes';
          saveButton.setAttribute("aria-label", "Save service settings changes");
        }, 2000);
      }
    });
    
    // Track changes to enable save button
    Object.keys(services).forEach(serviceKey => {
      const checkbox = settingsContent.querySelector(`input[data-service="${serviceKey}"]`);
      if (checkbox) {
        checkbox.addEventListener("change", () => {
          saveButton.disabled = false;
          saveButton.setAttribute("aria-disabled", "false");
          saveButton.classList.add('has-changes');
        });
      }
    });
    
    settingsContent.appendChild(saveButton);
  }

  /**
   * Display static service card (no API/feed)
   */
  displayStaticServiceCard(container, serviceKey, serviceDef) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = "external-service-card static";
    serviceLink.dataset.serviceKey = serviceKey;
    serviceLink.setAttribute("role", "listitem");
    serviceLink.setAttribute("aria-label", `${serviceDef.name} - ${serviceDef.statusText || 'Visit status page'} (opens in new tab)`);
    
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    iconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h3 = document.createElement("h3");
    h3.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = "service-status status-info";
    statusSpan.innerHTML = `<i class="fas fa-external-link-alt"></i> `;
    statusSpan.appendChild(document.createTextNode(serviceDef.statusText || 'Visit status page'));
    
    infoDiv.appendChild(h3);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    serviceLink.appendChild(headerDiv);
    
    container.appendChild(serviceLink);
  }

  /**
   * Display service card with loading state
   */
  displayServiceCardWithLoadingState(container, serviceKey, serviceDef) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = "external-service-card loading";
    serviceLink.dataset.serviceKey = serviceKey;
    serviceLink.setAttribute("role", "listitem");
    serviceLink.setAttribute("aria-label", `${serviceDef.name} - Loading status (opens in new tab)`);
    
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    iconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h3 = document.createElement("h3");
    h3.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = "service-status status-loading";
    statusSpan.innerHTML = `<i class="fas fa-spinner fa-spin"></i> `;
    statusSpan.appendChild(document.createTextNode("Loading..."));
    
    infoDiv.appendChild(h3);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    serviceLink.appendChild(headerDiv);
    
    container.appendChild(serviceLink);
  }

  /**
   * Update feed-based service status asynchronously
   */
  async updateFeedServiceStatus(serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        let apiUrl = `/api/external-services/feed?feed=${encodeURIComponent(serviceDef.feedType)}`;
        if (serviceDef.feedFilter) {
          apiUrl += `&filter=${encodeURIComponent(serviceDef.feedFilter)}`;
        }
        
        const response = await fetch(apiUrl, {
          signal: controller.signal,
          credentials: 'include'
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status) {
        throw new Error('Invalid feed response format');
      }

      // Find the card and update it
      const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
      if (!serviceCard) {
        console.error(`Card not found for service: ${serviceKey}`);
        return;
      }
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";
      
      // Update card class
      serviceCard.classList.remove("loading", "error");
      
      // Update status span
      const statusSpan = serviceCard.querySelector(".service-status");
      if (statusSpan) {
        statusSpan.className = `service-status status-${statusColor}`;
        statusSpan.setAttribute("role", "status");
        statusSpan.innerHTML = `<i class="fas fa-${statusIcon}" aria-hidden="true"></i> `;
        statusSpan.appendChild(document.createTextNode(this.utils.sanitizeInput(data.status.description)));
      }
      
      // Update card aria-label
      serviceCard.setAttribute("aria-label", `${serviceDef.name} - ${this.utils.sanitizeInput(data.status.description)} (opens in new tab)`);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} feed status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Update StatusPage.io service status asynchronously
   */
  async updateStatusPageServiceStatus(serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        const response = await fetch(serviceDef.api, {
          signal: controller.signal
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status || !data.status.indicator) {
        throw new Error('Invalid API response format');
      }

      // Find the card and update it
      const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
      if (!serviceCard) {
        console.error(`Card not found for service: ${serviceKey}`);
        return;
      }
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";
      
      // Update card class
      serviceCard.classList.remove("loading", "error");
      
      // Update status span
      const statusSpan = serviceCard.querySelector(".service-status");
      if (statusSpan) {
        statusSpan.className = `service-status status-${statusColor}`;
        statusSpan.setAttribute("role", "status");
        statusSpan.innerHTML = `<i class="fas fa-${statusIcon}" aria-hidden="true"></i> `;
        statusSpan.appendChild(document.createTextNode(this.utils.sanitizeInput(data.status.description)));
      }
      
      // Update card aria-label
      serviceCard.setAttribute("aria-label", `${serviceDef.name} - ${this.utils.sanitizeInput(data.status.description)} (opens in new tab)`);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Handle service loading errors
   */
  handleServiceError(serviceKey, serviceDef, error) {
    let errorMessage = 'Unable to fetch status';
    if (error.name === 'AbortError') {
      errorMessage = 'Request timed out';
    } else if (error.message && error.message.startsWith('HTTP error!')) {
      errorMessage = 'Service unavailable';
    }
    
    // Find the card and update it with error state
    const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
    if (!serviceCard) {
      console.error(`Card not found for service: ${serviceKey}`);
      return;
    }
    
    serviceCard.classList.remove("loading");
    serviceCard.classList.add("error");
    
    const statusSpan = serviceCard.querySelector(".service-status");
    if (statusSpan) {
      statusSpan.className = "service-status status-error";
      statusSpan.setAttribute("role", "alert");
      statusSpan.innerHTML = `<i class="fas fa-times-circle" aria-hidden="true"></i> `;
      statusSpan.appendChild(document.createTextNode(errorMessage));
    }
    
    // Update card aria-label
    serviceCard.setAttribute("aria-label", `${serviceDef.name} - ${errorMessage} (opens in new tab)`);
  }

  // ============ Cache Management ============

  /**
   * Get cached service data
   */
  getCachedService(serviceKey) {
    const cached = this.serviceCache.get(serviceKey);
    if (!cached) return null;
    
    const now = Date.now();
    if (now - cached.timestamp > this.cacheTTL) {
      this.serviceCache.delete(serviceKey);
      return null;
    }
    
    return cached.data;
  }

  /**
   * Set cached service data
   */
  setCachedService(serviceKey, data) {
    this.serviceCache.set(serviceKey, {
      data: data,
      timestamp: Date.now()
    });
  }

  /**
   * Clear service cache
   */
  clearCache() {
    this.serviceCache.clear();
  }

  // ============ Cookie Management ============

  /**
   * Get cookie value
   */
  getCookie(name) {
    const nameEQ = name + "=";
    const ca = document.cookie.split(';');
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i];
      while (c.charAt(0) === ' ') c = c.substring(1, c.length);
      if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
  }

  /**
   * Set cookie value
   */
  setCookie(name, value, days = 365) {
    let expires = "";
    if (days) {
      const date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    // Set cookie with SameSite=Lax for security
    document.cookie = name + "=" + (value || "") + expires + "; path=/; SameSite=Lax";
  }

  /**
   * Delete cookie
   */
  deleteCookie(name) {
    document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  }

  // ============ Service Preferences ============

  /**
   * Load service preferences from cookie
   */
  loadServicePreferences() {
    try {
      // Try to load from cookie first
      const cookiePrefs = this.getCookie('servicePreferences');
      if (cookiePrefs) {
        try {
          const parsed = JSON.parse(decodeURIComponent(cookiePrefs));
          // Validate it's an object with expected structure
          if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
            return parsed;
          }
        } catch (parseError) {
          console.error('Failed to parse cookie preferences:', parseError);
          // Clear invalid cookie
          this.deleteCookie('servicePreferences');
        }
      }
      
      // Return null if no valid preferences found - will use defaults
      return null;
    } catch (error) {
      console.error('Failed to load service preferences:', error);
      return null;
    }
  }

  /**
   * Get service order from cookie
   */
  getServiceOrder() {
    const orderCookie = this.getCookie('serviceOrder');
    if (orderCookie) {
      try {
        return JSON.parse(decodeURIComponent(orderCookie));
      } catch (e) {
        console.error('Failed to parse service order:', e);
      }
    }
    // Default alphabetical order by category
    return [
      // Hosting & Infrastructure
      'aws', 'cloudflare', 'cloudways', 'digitalocean', 'googlecloud', 'godaddy', 'hostinger', 'jetpackapi', 'kinsta', 
      'linode', 'oracle', 'ovh', 'scaleway', 'upcloud', 'vercel', 'vultr', 'wordpressapi', 'wpcloudapi',
      // Developer Tools
      'codacy', 'github', 'gitlab', 'googleworkspace', 'metalogin', 'notion', 'pipedream', 'trello', 'twilio',
      // E-Commerce & Payments
      'coinbase', 'intuit', 'metafb', 'paypal', 'recurly', 'shopify', 'square', 'stripe', 'woocommercepay',
      // Email Services
      'brevo', 'mailersend', 'mailgun', 'mailjet', 'mailpoet', 'postmark', 'resend', 'sendgrid', 'sendlayer', 'smtp2go', 'sparkpost', 'zoho',
      // Communication
      'discord', 'slack', 'zoom',
      // Media & Content
      'dropbox', 'reddit', 'spotify', 'udemy', 'vimeo', 'wistia',
      // Gaming
      'epicgames',
      // AI & Machine Learning
      'anthropic', 'openai',
      // Advertising
      'googleads', 'googlesearch', 'metafbs', 'metamarketingapi', 'microsoftads',
      // Security
      'flare', 'letsencrypt'
    ];
  }

  /**
   * Save service order to cookie
   */
  saveServiceOrder(orderArray) {
    this.setCookie('serviceOrder', encodeURIComponent(JSON.stringify(orderArray)), 365);
  }

  // ============ Notifications ============

  /**
   * Show notification to user
   */
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.classList.add('slide-out');
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }
}
