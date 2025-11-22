// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v=2025.11.21.16';
import { SERVICE_DEFINITIONS } from './services-config.js?v=2025.11.21.16';

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
    settingsToggle.innerHTML = `
      <i class="fas fa-cog"></i>
      <span>Service Settings</span>
      <i class="fas fa-chevron-down toggle-icon"></i>
    `;
    
    const settingsContent = document.createElement("div");
    settingsContent.className = "settings-content collapsed";
    
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
        <button class="category-toggle-all-btn" data-category="${category}">
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
      const toggleBtn = categoryHeader.querySelector(".category-toggle-all-btn");
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
    saveButton.className = "settings-save-btn";
    saveButton.innerHTML = '<i class="fas fa-save"></i> Save Changes';
    saveButton.disabled = true;
    
    saveButton.addEventListener("click", async () => {
      try {
        saveButton.disabled = true;
        saveButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
        
        // Load current preferences from cookie
        let currentPreferences = this.loadServicePreferences() || {};
        
        // Apply pending changes to preferences
        Object.assign(currentPreferences, pendingChanges);
        
        // Save to cookie (client-side only)
        this.setCookie('servicePreferences', encodeURIComponent(JSON.stringify(currentPreferences)), 365);
        
        // Update local services object
        Object.assign(services, pendingChanges);
        
        // Clear pending changes
        for (const key in pendingChanges) {
          delete pendingChanges[key];
        }
        
        saveButton.innerHTML = '<i class="fas fa-check"></i> Saved!';
        setTimeout(() => {
          saveButton.innerHTML = '<i class="fas fa-save"></i> Save Changes';
          saveButton.classList.remove('has-changes');
          saveButton.disabled = true;
        }, 2000);
        
        // Reload services display to show updated preferences
        this.initialized = false; // Reset initialization flag to allow reload
        await this.init();
        
        this.showNotification('Service preferences saved', 'success');
      } catch (error) {
        console.error("Save error:", error);
        saveButton.innerHTML = '<i class="fas fa-times"></i> Save Failed';
        saveButton.disabled = false;
        setTimeout(() => {
          saveButton.innerHTML = '<i class="fas fa-save"></i> Save Changes';
        }, 2000);
        this.showNotification('Failed to save preferences', 'error');
      }
    });
    
    // Track changes to enable save button
    Object.keys(services).forEach(serviceKey => {
      const checkbox = settingsContent.querySelector(`input[data-service="${serviceKey}"]`);
      if (checkbox) {
        checkbox.addEventListener("change", () => {
          saveButton.disabled = false;
          saveButton.classList.add('has-changes');
        });
      }
    });
    
    settingsContent.appendChild(saveButton);
  }

  // ============ Card Creation Helpers ============

  /**
   * Create service card header (icon + info)
   */
  createServiceCardHeader(serviceDef, statusClassName, statusContent) {
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
    statusSpan.className = `service-status ${statusClassName}`;
    statusSpan.innerHTML = statusContent;
    
    infoDiv.appendChild(h3);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    
    return headerDiv;
  }

  /**
   * Create base service card element
   */
  createBaseServiceCard(serviceKey, serviceDef, cardClass, headerElement) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = `external-service-card ${cardClass}`;
    serviceLink.dataset.serviceKey = serviceKey;
    serviceLink.appendChild(headerElement);
    return serviceLink;
  }

  /**
   * Display static service card (no API/feed)
   */
  displayStaticServiceCard(container, serviceKey, serviceDef) {
    const statusContent = `<i class="fas fa-external-link-alt"></i> `;
    const contentNode = document.createTextNode(serviceDef.statusText || 'Visit status page');
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-info", statusContent);
    const statusSpan = headerDiv.querySelector(".service-status");
    statusSpan.appendChild(contentNode);
    
    const serviceLink = this.createBaseServiceCard(serviceKey, serviceDef, "static", headerDiv);
    container.appendChild(serviceLink);
  }

  /**
   * Display service card with loading state
   */
  displayServiceCardWithLoadingState(container, serviceKey, serviceDef) {
    const statusContent = `<i class="fas fa-spinner fa-spin"></i> `;
    const contentNode = document.createTextNode("Loading...");
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-loading", statusContent);
    const statusSpan = headerDiv.querySelector(".service-status");
    statusSpan.appendChild(contentNode);
    
    const serviceLink = this.createBaseServiceCard(serviceKey, serviceDef, "loading", headerDiv);
    container.appendChild(serviceLink);
  }

  // ============ Status Update Helpers ============

  /**
   * Extract and determine status display values
   */
  getStatusDisplayValues(statusIndicator, isFeed = false) {
    const statusClass = statusIndicator === "none" ? "operational" : statusIndicator;
    // Map icons per status
    let statusIcon = 'exclamation-triangle';
    if (statusClass === 'operational') statusIcon = 'check-circle';
    else if (statusClass === 'major') statusIcon = 'times-circle';
    else if (statusClass === 'minor') statusIcon = 'exclamation-triangle';

    // For Atom/RSS feeds, map major->error, minor->warning
    if (isFeed) {
      const statusColor = statusClass === 'operational' ? 'success' : (statusClass === 'major' ? 'error' : 'warning');
      return { statusClass, statusIcon, statusColor };
    }

    const statusColor = statusClass === 'operational' ? 'success' : statusClass === 'minor' ? 'warning' : 'error';
    return { statusClass, statusIcon, statusColor };
  }

  /**
   * Update service card with status data
   */
  updateServiceCardStatus(serviceCard, statusDescription, statusClass, statusIcon, statusColor) {
    // Update card class
    serviceCard.classList.remove("loading", "error", "status-success", "status-warning", "status-error");
    
    // Update status span
    const statusSpan = serviceCard.querySelector(".service-status");
    if (statusSpan) {
      statusSpan.className = `service-status status-${statusColor}`;
      statusSpan.innerHTML = `<i class="fas fa-${statusIcon}"></i> `;
      statusSpan.appendChild(document.createTextNode(this.utils.sanitizeInput(statusDescription)));
    }

    // Add card-level status class for visual emphasis
    serviceCard.classList.add(`status-${statusColor}`);
  }

  /**
   * Fetch data with timeout and caching support
   */
  async fetchServiceData(fetchFn, serviceKey) {
    // Check cache first
    let data = this.getCachedService(serviceKey);
    
    if (!data) {
      // Not in cache, fetch from API
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 60000);
      
      try {
        const response = await fetchFn(controller.signal);
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.setCachedService(serviceKey, data);
      } catch (error) {
        clearTimeout(timeoutId);
        throw error;
      }
    }
    
    return data;
  }

  /**
   * Get service card DOM element for a given key and log if not found
   */
  getServiceCardElement(serviceKey, serviceDef) {
    const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
    if (!serviceCard) {
      const name = serviceDef && serviceDef.name ? serviceDef.name : serviceKey;
      console.error(`Card not found for service: ${serviceKey} (${name})`);
      return null;
    }
    return serviceCard;
  }

  /**
   * Update feed-based service status asynchronously
   */
  async updateFeedServiceStatus(serviceKey, serviceDef) {
    try {
      const data = await this.fetchServiceData((signal) => {
        let apiUrl = `/api/external-services/feed?feed=${encodeURIComponent(serviceDef.feedType)}`;
        if (serviceDef.feedFilter) {
          apiUrl += `&filter=${encodeURIComponent(serviceDef.feedFilter)}`;
        }
        
        return fetch(apiUrl, {
          signal: signal,
          credentials: 'include'
        });
      }, serviceKey);
      
      if (!data || !data.status) {
        throw new Error('Invalid feed response format');
      }

      // Find the card and update it
      const serviceCard = this.getServiceCardElement(serviceKey, serviceDef);
      if (!serviceCard) return;
      
      const { statusClass, statusIcon, statusColor } = this.getStatusDisplayValues(data.status.indicator, true);
      this.updateServiceCardStatus(serviceCard, data.status.description, statusClass, statusIcon, statusColor);
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
      const data = await this.fetchServiceData((signal) => {
        return fetch(serviceDef.api, {
          signal: signal
        });
      }, serviceKey);
      
      if (!data || !data.status || !data.status.indicator) {
        throw new Error('Invalid API response format');
      }

      // Find the card and update it
      const serviceCard = this.getServiceCardElement(serviceKey, serviceDef);
      if (!serviceCard) return;
      
      const { statusClass, statusIcon, statusColor } = this.getStatusDisplayValues(data.status.indicator, false);
      this.updateServiceCardStatus(serviceCard, data.status.description, statusClass, statusIcon, statusColor);
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
      statusSpan.innerHTML = `<i class="fas fa-times-circle"></i> `;
      statusSpan.appendChild(document.createTextNode(errorMessage));
    }
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

  // ============ Drag and Drop ============

  /**
   * Enable drag-and-drop for service cards
   */
  enableServiceDragDrop(container) {
    const serviceCards = container.querySelectorAll('.external-service-card');
    let draggedElement = null;

    serviceCards.forEach(card => {
      card.draggable = true;

      card.addEventListener('dragstart', (e) => {
        draggedElement = card;
        card.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/html', card.innerHTML);
      });

      card.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        
        const targetCard = e.target.closest('.external-service-card');
        if (targetCard && targetCard !== draggedElement) {
          targetCard.classList.add('drag-over');
        }
      });

      card.addEventListener('dragenter', (e) => {
        const targetCard = e.target.closest('.external-service-card');
        if (targetCard && targetCard !== draggedElement) {
          targetCard.classList.add('drag-over');
        }
      });

      card.addEventListener('dragleave', (e) => {
        const targetCard = e.target.closest('.external-service-card');
        if (targetCard) {
          targetCard.classList.remove('drag-over');
        }
      });

      card.addEventListener('drop', (e) => {
        e.preventDefault();
        
        const targetCard = e.target.closest('.external-service-card');
        if (targetCard && targetCard !== draggedElement) {
          targetCard.classList.remove('drag-over');
          
          // Swap positions
          const allCards = Array.from(container.querySelectorAll('.external-service-card'));
          const draggedIndex = allCards.indexOf(draggedElement);
          const targetIndex = allCards.indexOf(targetCard);
          
          if (draggedIndex < targetIndex) {
            targetCard.parentNode.insertBefore(draggedElement, targetCard.nextSibling);
          } else {
            targetCard.parentNode.insertBefore(draggedElement, targetCard);
          }
          
          // Save new order
          this.saveCardOrder();
        }
      });

      card.addEventListener('dragend', () => {
        card.classList.remove('dragging');
        // Remove drag-over from all cards
        container.querySelectorAll('.external-service-card').forEach(c => {
          c.classList.remove('drag-over');
        });
      });
    });
  }

  /**
   * Save current card order to cookie
   */
  saveCardOrder() {
    const cards = document.querySelectorAll('.external-service-card');
    const orderArray = Array.from(cards).map(card => card.dataset.serviceKey);
    this.saveServiceOrder(orderArray);
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
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 15px 20px;
      background: ${type === 'success' ? '#00d4aa' : type === 'error' ? '#f44' : '#00a8ff'};
      color: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      z-index: 10000;
      animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }
}
