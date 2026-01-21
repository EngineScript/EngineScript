// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v=2025.12.01.1';
import { SERVICE_DEFINITIONS } from './services-config.js?v=2025.12.01.1';

export class ExternalServicesManager {
  constructor(containerSelector, settingsContainerSelector) {
    this.utils = new DashboardUtils();
    this.container = document.querySelector(containerSelector);
    this.settingsContainer = document.querySelector(settingsContainerSelector);
    
    // State management with LRU cache (5-minute TTL, max 100 entries)
    this.serviceCache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes in milliseconds
    this.cacheMaxSize = 100; // Limit cache size to prevent memory growth
    this.initialized = false; // Track if services have been loaded (lazy loading)
    
    // Limits concurrent requests to prevent overwhelming the server/browser
    this.maxConcurrentRequests = 6;
    this.activeRequests = 0;
    this.requestQueue = [];
    
    // Keyboard navigation state for accessibility
    this.reorderMode = false;
    this.selectedCard = null;
    this.keyboardHandler = null;
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

      // Get service definitions and preferences
      const serviceDefinitions = this.getServiceDefinitions();
      const preferences = this.loadServicePreferences() || {};
      const services = this.buildServicesObject(serviceDefinitions);

      // Render settings panel
      this.renderServiceSettings(this.settingsContainer, services, serviceDefinitions);

      // Get ordered and enabled services
      const orderedServiceKeys = this.getOrderedServiceKeys(services);
      const enabledServices = this.filterEnabledServices(orderedServiceKeys, serviceDefinitions, preferences);

      // Show empty state if no services enabled
      if (enabledServices.length === 0) {
        this.renderEmptyState();
        return;
      }

      // Group and render services by category
      const servicesByCategory = this.groupServicesByCategory(orderedServiceKeys, serviceDefinitions, preferences);
      this.renderServiceCategories(servicesByCategory);
      
      // Enable drag and drop for service cards
      this.enableServiceDragDrop(this.container);
    } catch (error) {
      console.error('Failed to load external services:', error);
      this.renderErrorState();
    }
  }

  /**
   * Build services object from definitions
   */
  buildServicesObject(serviceDefinitions) {
    const services = {};
    Object.keys(serviceDefinitions).forEach(key => {
      services[key] = true;
    });
    return services;
  }

  /**
   * Get service keys in custom order, adding any new services
   */
  getOrderedServiceKeys(services) {
    const serviceOrder = this.getServiceOrder();
    const orderedKeys = serviceOrder.filter(key => services[key]);
    
    // Add any new services not in the saved order
    Object.keys(services).forEach(key => {
      if (!orderedKeys.includes(key)) {
        orderedKeys.push(key);
      }
    });
    
    return orderedKeys;
  }

  /**
   * Filter to only enabled services
   */
  filterEnabledServices(orderedServiceKeys, serviceDefinitions, preferences) {
    return orderedServiceKeys.filter(key => {
      return serviceDefinitions[key] && preferences[key] === true;
    });
  }

  /**
   * Render empty state when no services are enabled
   */
  renderEmptyState() {
    const emptyState = document.createElement("div");
    emptyState.className = "empty-state";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = "empty-state-icon";
    const icon = document.createElement("i");
    icon.className = "fas fa-toggle-off";
    iconDiv.appendChild(icon);
    
    const h3 = document.createElement("h3");
    h3.textContent = "No Services Selected";
    
    const p = document.createElement("p");
    p.textContent = 'Click the "Service Settings" button above to enable external service monitoring.';
    
    emptyState.appendChild(iconDiv);
    emptyState.appendChild(h3);
    emptyState.appendChild(p);
    this.container.appendChild(emptyState);
  }

  /**
   * Render error state when loading fails
   */
  renderErrorState() {
    this.container.innerHTML = "";
    
    const errorDiv = document.createElement("div");
    errorDiv.className = "error-state";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = "error-icon";
    const icon = document.createElement("i");
    icon.className = "fas fa-exclamation-circle";
    iconDiv.appendChild(icon);
    
    const h3 = document.createElement("h3");
    h3.textContent = "Error Loading External Services";
    
    const p = document.createElement("p");
    p.textContent = "Failed to fetch external service status. Please try again later.";
    
    errorDiv.appendChild(iconDiv);
    errorDiv.appendChild(h3);
    errorDiv.appendChild(p);
    this.container.appendChild(errorDiv);
  }

  /**
   * Group services by category
   */
  groupServicesByCategory(orderedServiceKeys, serviceDefinitions, preferences) {
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
    
    return servicesByCategory;
  }

  /**
   * Render service categories and their cards
   */
  renderServiceCategories(servicesByCategory) {
    for (const category in servicesByCategory) {
      // Create and append category header
      const categoryHeader = this.createCategoryHeader(category);
      this.container.appendChild(categoryHeader);

      // Create category container and render cards
      const categoryContainer = this.createCategoryContainer(category);
      this.renderCategoryCards(categoryContainer, servicesByCategory[category]);
      this.container.appendChild(categoryContainer);
    }
  }

  /**
   * Create category header element
   */
  createCategoryHeader(category) {
    const categoryHeader = document.createElement("div");
    categoryHeader.className = "service-category-header";
    const categoryH3 = document.createElement("h3");
    categoryH3.textContent = category;
    categoryHeader.appendChild(categoryH3);
    return categoryHeader;
  }

  /**
   * Create category container element
   */
  createCategoryContainer(category) {
    const categoryContainer = document.createElement("div");
    categoryContainer.className = "service-category-grid";
    categoryContainer.dataset.category = category;
    return categoryContainer;
  }

  /**
   * Render service cards within a category container
   */
  renderCategoryCards(container, services) {
    for (const { key: serviceKey, def: serviceDef } of services) {
      if (!serviceDef.useFeed && !serviceDef.corsEnabled && !serviceDef.api) {
        // Display static card immediately (e.g., AWS)
        this.displayStaticServiceCard(container, serviceKey, serviceDef);
      } else {
        // Display card with loading state, then fetch status
        this.displayServiceCardWithLoadingState(container, serviceKey, serviceDef);
        this.fetchServiceStatusAsync(serviceKey, serviceDef);
      }
    }
  }

  /**
   * Fetch service status asynchronously (non-blocking)
   */
  fetchServiceStatusAsync(serviceKey, serviceDef) {
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
    
    // Track pending changes (shared across components)
    const pendingChanges = {};
    
    // Create main UI structure
    const { settingsToggle, settingsContent } = this.createSettingsStructure();
    settingsContainer.appendChild(settingsToggle);
    settingsContainer.appendChild(settingsContent);

    // Group services by category and render
    const categories = this.groupServicesForSettings(services, serviceDefinitions);
    const categoryOrder = this.getCategoryOrder();

    for (const category of categoryOrder) {
      if (!categories[category]) continue;
      const categorySection = this.createSettingsCategorySection(
        category, categories[category], services, serviceDefinitions, pendingChanges
      );
      settingsContent.appendChild(categorySection);
    }

    // Create and append save button
    const saveButton = this.createSaveButton(settingsContent, services, pendingChanges);
    settingsContent.appendChild(saveButton);
  }

  /**
   * Create settings panel structure (toggle button and content container)
   */
  createSettingsStructure() {
    const settingsToggle = document.createElement("button");
    settingsToggle.className = "settings-toggle-btn";
    
    const cogIcon = document.createElement("i");
    cogIcon.className = "fas fa-cog";
    const textSpan = document.createElement("span");
    textSpan.textContent = "Service Settings";
    const chevronIcon = document.createElement("i");
    chevronIcon.className = "fas fa-chevron-down toggle-icon";
    
    settingsToggle.appendChild(cogIcon);
    settingsToggle.appendChild(textSpan);
    settingsToggle.appendChild(chevronIcon);
    
    const settingsContent = document.createElement("div");
    settingsContent.className = "settings-content collapsed";
    
    const settingsHeader = document.createElement("div");
    settingsHeader.className = "settings-header";
    const headerP = document.createElement("p");
    headerP.textContent = 'Toggle services to show/hide on the dashboard. Drag service cards to reorder them. Click "Save Changes" to apply. Services are organized by category.';
    settingsHeader.appendChild(headerP);
    settingsContent.appendChild(settingsHeader);
    
    // Toggle collapse behavior
    settingsToggle.addEventListener("click", () => {
      const isCollapsed = settingsContent.classList.toggle("collapsed");
      const icon = settingsToggle.querySelector(".toggle-icon");
      icon.className = isCollapsed ? "fas fa-chevron-down toggle-icon" : "fas fa-chevron-up toggle-icon";
    });
    
    return { settingsToggle, settingsContent };
  }

  /**
   * Group services by category for settings panel
   */
  groupServicesForSettings(services, serviceDefinitions) {
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
    return categories;
  }

  /**
   * Get ordered list of categories for settings display
   */
  getCategoryOrder() {
    return [
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
  }

  /**
   * Create a category section for settings panel
   */
  createSettingsCategorySection(category, serviceKeys, services, serviceDefinitions, pendingChanges) {
    const categorySection = document.createElement("div");
    categorySection.className = "category-section";

    // Create header with toggle all button
    const categoryHeader = this.createSettingsCategoryHeader(category);
    categorySection.appendChild(categoryHeader);

    // Create services grid with checkboxes
    const { servicesGrid, categoryCheckboxes } = this.createServicesGrid(
      serviceKeys, services, serviceDefinitions, pendingChanges
    );
    categorySection.appendChild(servicesGrid);

    // Wire up toggle all button
    const toggleBtn = categoryHeader.querySelector(".category-toggle-all-btn");
    toggleBtn.addEventListener("click", () => {
      const allEnabled = categoryCheckboxes.every(cb => cb.checked);
      categoryCheckboxes.forEach(cb => {
        cb.checked = !allEnabled;
        cb.dispatchEvent(new Event('change'));
      });
    });

    return categorySection;
  }

  /**
   * Create category header with toggle all button
   */
  createSettingsCategoryHeader(category) {
    const categoryHeader = document.createElement("div");
    categoryHeader.className = "category-header";
    
    const categorySpan = document.createElement("span");
    categorySpan.textContent = category;
    categoryHeader.appendChild(categorySpan);
    
    const toggleAllBtn = document.createElement("button");
    toggleAllBtn.className = "category-toggle-all-btn";
    toggleAllBtn.dataset.category = category;
    
    const toggleText = document.createElement("span");
    toggleText.className = "toggle-all-text";
    toggleText.textContent = "Toggle All";
    toggleAllBtn.appendChild(toggleText);
    
    const toggleIcon = document.createElement("i");
    toggleIcon.className = "fas fa-toggle-on";
    toggleAllBtn.appendChild(toggleIcon);
    
    categoryHeader.appendChild(toggleAllBtn);
    return categoryHeader;
  }

  /**
   * Create services grid with checkboxes for each service
   */
  createServicesGrid(serviceKeys, services, serviceDefinitions, pendingChanges) {
    const servicesGrid = document.createElement("div");
    servicesGrid.className = "services-grid";
    const categoryCheckboxes = [];
    
    serviceKeys.forEach(serviceKey => {
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

    return { servicesGrid, categoryCheckboxes };
  }

  /**
   * Create save button with click handler
   */
  createSaveButton(settingsContent, services, pendingChanges) {
    const saveButton = document.createElement("button");
    saveButton.className = "settings-save-btn";
    
    const saveIcon = document.createElement("i");
    saveIcon.className = "fas fa-save";
    saveButton.appendChild(saveIcon);
    saveButton.appendChild(document.createTextNode(" Save Changes"));
    saveButton.disabled = true;
    
    // Save click handler
    saveButton.addEventListener("click", async () => {
      await this.handleSavePreferences(saveButton, services, pendingChanges);
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
    
    return saveButton;
  }

  /**
   * Handle save preferences button click
   */
  async handleSavePreferences(saveButton, services, pendingChanges) {
    try {
      saveButton.disabled = true;
      saveButton.textContent = '';
      const spinnerIcon = document.createElement("i");
      spinnerIcon.className = "fas fa-spinner fa-spin";
      saveButton.appendChild(spinnerIcon);
      saveButton.appendChild(document.createTextNode(" Saving..."));
      
      // Load and update preferences
      let currentPreferences = this.loadServicePreferences() || {};
      Object.assign(currentPreferences, pendingChanges);
      
      // Save to cookie
      this.setCookie('servicePreferences', encodeURIComponent(JSON.stringify(currentPreferences)), 365);
      Object.assign(services, pendingChanges);
      
      // Clear pending changes
      for (const key in pendingChanges) {
        delete pendingChanges[key];
      }
      
      // Show success state
      saveButton.textContent = '';
      const checkIcon = document.createElement("i");
      checkIcon.className = "fas fa-check";
      saveButton.appendChild(checkIcon);
      saveButton.appendChild(document.createTextNode(" Saved!"));
      
      setTimeout(() => {
        saveButton.textContent = '';
        const saveIcon = document.createElement("i");
        saveIcon.className = "fas fa-save";
        saveButton.appendChild(saveIcon);
        saveButton.appendChild(document.createTextNode(" Save Changes"));
        saveButton.classList.remove('has-changes');
        saveButton.disabled = true;
      }, 2000);
      
      // Reload services display
      this.initialized = false;
      await this.init();
      
      this.showNotification('Service preferences saved', 'success');
    } catch (error) {
      console.error("Save error:", error);
      saveButton.textContent = '';
      const timesIcon = document.createElement("i");
      timesIcon.className = "fas fa-times";
      saveButton.appendChild(timesIcon);
      saveButton.appendChild(document.createTextNode(" Save Failed"));
      saveButton.disabled = false;
      
      setTimeout(() => {
        saveButton.textContent = '';
        const saveIcon = document.createElement("i");
        saveIcon.className = "fas fa-save";
        saveButton.appendChild(saveIcon);
        saveButton.appendChild(document.createTextNode(" Save Changes"));
      }, 2000);
      
      this.showNotification('Failed to save preferences', 'error');
    }
  }

  // ============ Card Creation Helpers ============

  /**
   * Create service card header (icon + info)
   * @param {Object} serviceDef - Service definition
   * @param {string} statusClassName - CSS class for status
   * @param {string} statusIconClass - FontAwesome icon class (e.g., 'fa-spinner fa-spin')
   */
  createServiceCardHeader(serviceDef, statusClassName, statusIconClass) {
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    
    // Use DOM methods instead of innerHTML for security
    const iconElement = document.createElement("i");
    // Validate icon class contains only safe characters (alphanumeric, hyphens)
    const safeIcon = (serviceDef.icon || 'fa-question').replace(/[^a-zA-Z0-9-]/g, '');
    iconElement.className = `fas ${safeIcon}`;
    iconDiv.appendChild(iconElement);
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h3 = document.createElement("h3");
    h3.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = `service-status ${statusClassName}`;
    
    // Create status icon using DOM methods instead of innerHTML
    const statusIcon = document.createElement("i");
    // Validate status icon class contains only safe characters
    const safeStatusIcon = (statusIconClass || 'fa-question').replace(/[^a-zA-Z0-9- ]/g, '');
    statusIcon.className = `fas ${safeStatusIcon}`;
    statusSpan.appendChild(statusIcon);
    statusSpan.appendChild(document.createTextNode(" ")); // Add space after icon
    
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
    const statusIconClass = "fa-external-link-alt";
    const contentNode = document.createTextNode(serviceDef.statusText || 'Visit status page');
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-info", statusIconClass);
    const statusSpan = headerDiv.querySelector(".service-status");
    statusSpan.appendChild(contentNode);
    
    const serviceLink = this.createBaseServiceCard(serviceKey, serviceDef, "static", headerDiv);
    // Add success status class for green border like operational services
    serviceLink.classList.add('status-success');
    container.appendChild(serviceLink);
  }

  /**
   * Display service card with loading state
   */
  displayServiceCardWithLoadingState(container, serviceKey, serviceDef) {
    const statusIconClass = "fa-spinner fa-spin";
    const contentNode = document.createTextNode("Loading...");
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-loading", statusIconClass);
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
    
    // Update status span using DOM methods instead of innerHTML
    const statusSpan = serviceCard.querySelector(".service-status");
    if (statusSpan) {
      statusSpan.className = `service-status status-${statusColor}`;
      // Clear existing content
      statusSpan.textContent = '';
      // Create icon element safely
      const iconElement = document.createElement("i");
      // Validate icon class contains only safe characters (alphanumeric, hyphens)
      const safeIcon = (statusIcon || 'fa-question').replace(/[^a-zA-Z0-9-]/g, '');
      iconElement.className = `fas fa-${safeIcon}`;
      statusSpan.appendChild(iconElement);
      statusSpan.appendChild(document.createTextNode(" " + this.utils.sanitizeInput(statusDescription)));
    }

    // Add card-level status class for visual emphasis
    serviceCard.classList.add(`status-${statusColor}`);
  }

  /**
   * Queue a request with concurrency limiting
   * Prevents overwhelming browser/server with too many concurrent requests
   * @param {Function} requestFn - Async function that performs the actual request
   * @returns {Promise} - Resolves when request completes
   */
  async queueRequest(requestFn) {
    return new Promise((resolve, reject) => {
      const executeRequest = async () => {
        this.activeRequests++;
        try {
          const result = await requestFn();
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          this.activeRequests--;
          this.processQueue();
        }
      };

      if (this.activeRequests < this.maxConcurrentRequests) {
        executeRequest();
      } else {
        this.requestQueue.push(executeRequest);
      }
    });
  }

  /**
   * Process queued requests when a slot becomes available
   */
  processQueue() {
    while (this.requestQueue.length > 0 && this.activeRequests < this.maxConcurrentRequests) {
      const nextRequest = this.requestQueue.shift();
      nextRequest();
    }
  }

  /**
   * Fetch data with timeout, caching support, and concurrency limiting
   */
  async fetchServiceData(fetchFn, serviceKey) {
    // Check cache first - no need to queue if cached
    let data = this.getCachedService(serviceKey);
    
    if (!data) {
      // Not in cache, queue the fetch request with concurrency limiting
      data = await this.queueRequest(async () => {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        try {
          const response = await fetchFn(controller.signal);
          clearTimeout(timeoutId);
          
          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }
          
          const responseData = await response.json();
          
          // Cache the response
          this.setCachedService(serviceKey, responseData);
          return responseData;
        } catch (error) {
          clearTimeout(timeoutId);
          throw error;
        }
      });
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
      // Clear existing content and use DOM methods instead of innerHTML
      statusSpan.textContent = '';
      const iconElement = document.createElement("i");
      iconElement.className = "fas fa-times-circle";
      statusSpan.appendChild(iconElement);
      statusSpan.appendChild(document.createTextNode(" " + errorMessage));
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
   * Set cached service data with LRU eviction
   * Implements LRU cache with max size of 100 entries
   */
  setCachedService(serviceKey, data) {
    // LRU behavior: if key exists, delete it first so it moves to end of Map
    if (this.serviceCache.has(serviceKey)) {
      this.serviceCache.delete(serviceKey);
    }
    
    // Evict oldest entries if cache is full (LRU eviction)
    while (this.serviceCache.size >= this.cacheMaxSize) {
      const oldestKey = this.serviceCache.keys().next().value;
      this.serviceCache.delete(oldestKey);
    }
    
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
    // Set cookie with Secure, HttpOnly cannot be set via JS, SameSite=Strict for maximum security
    // Secure flag ensures cookie only sent over HTTPS
    // SameSite=Strict prevents CSRF attacks (stricter than Lax)
    document.cookie = name + "=" + (value || "") + expires + "; path=/; SameSite=Strict; Secure";
  }

  /**
   * Delete cookie
   * Include Secure flag in deletion for consistency
   */
  deleteCookie(name) {
    document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; SameSite=Strict; Secure';
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

    serviceCards.forEach((card, index) => {
      card.draggable = true;
      
      // Add tabindex for keyboard accessibility
      card.setAttribute('tabindex', '0');
      card.setAttribute('role', 'listitem');
      card.setAttribute('aria-label', `${card.querySelector('h3')?.textContent || 'Service'} - Press Enter to enter reorder mode, then use arrow keys to move`);

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
    
    // Enable keyboard navigation for accessibility
    this.enableKeyboardNavigation(container);
  }

  // ============ Keyboard Navigation (Accessibility) ============

  /**
   * Enable keyboard navigation for service card reordering
   * Implements arrow key navigation and Enter to toggle reorder mode
   * This is an accessibility alternative to drag-and-drop
   */
  enableKeyboardNavigation(container) {
    // Remove existing handler if present (prevents duplicate listeners on reload)
    if (this.keyboardHandler) {
      container.removeEventListener('keydown', this.keyboardHandler);
    }
    
    this.keyboardHandler = (e) => {
      const focusedCard = document.activeElement;
      
      // Only handle events on service cards
      if (!focusedCard || !focusedCard.classList.contains('external-service-card')) {
        return;
      }
      
      const allCards = Array.from(container.querySelectorAll('.external-service-card'));
      const currentIndex = allCards.indexOf(focusedCard);
      
      if (currentIndex === -1) return;
      
      switch (e.key) {
        case 'Enter':
        case ' ':
          // Toggle reorder mode on Enter or Space
          e.preventDefault();
          this.toggleReorderMode(focusedCard);
          break;
          
        case 'Escape':
          // Exit reorder mode
          if (this.reorderMode) {
            e.preventDefault();
            this.exitReorderMode();
          }
          break;
          
        case 'ArrowUp':
        case 'ArrowLeft':
          e.preventDefault();
          if (this.reorderMode && this.selectedCard === focusedCard) {
            // Move card up/left in reorder mode
            this.moveCardUp(focusedCard, allCards, currentIndex);
          } else {
            // Navigate to previous card
            this.focusPreviousCard(allCards, currentIndex);
          }
          break;
          
        case 'ArrowDown':
        case 'ArrowRight':
          e.preventDefault();
          if (this.reorderMode && this.selectedCard === focusedCard) {
            // Move card down/right in reorder mode
            this.moveCardDown(focusedCard, allCards, currentIndex);
          } else {
            // Navigate to next card
            this.focusNextCard(allCards, currentIndex);
          }
          break;
          
        case 'Home':
          // Move to first card
          e.preventDefault();
          if (allCards.length > 0) {
            allCards[0].focus();
          }
          break;
          
        case 'End':
          // Move to last card
          e.preventDefault();
          if (allCards.length > 0) {
            allCards[allCards.length - 1].focus();
          }
          break;
      }
    };
    
    container.addEventListener('keydown', this.keyboardHandler);
  }

  /**
   * Toggle reorder mode for a card
   * When in reorder mode, arrow keys move the card instead of navigating
   */
  toggleReorderMode(card) {
    if (this.reorderMode && this.selectedCard === card) {
      // Exit reorder mode
      this.exitReorderMode();
      this.showNotification('Reorder mode exited. Order saved.', 'info');
    } else {
      // Enter reorder mode
      this.reorderMode = true;
      this.selectedCard = card;
      card.classList.add('reorder-active');
      card.setAttribute('aria-grabbed', 'true');
      
      // Announce to screen readers
      this.announceToScreenReader(`Reorder mode. Use arrow keys to move ${card.querySelector('h3')?.textContent || 'service'}. Press Enter or Escape to exit.`);
      this.showNotification('Reorder mode: Use arrow keys to move, Enter/Escape to exit', 'info');
    }
  }

  /**
   * Exit reorder mode
   */
  exitReorderMode() {
    if (this.selectedCard) {
      this.selectedCard.classList.remove('reorder-active');
      this.selectedCard.setAttribute('aria-grabbed', 'false');
    }
    this.reorderMode = false;
    this.selectedCard = null;
  }

  /**
   * Move card up (toward beginning of list)
   */
  moveCardUp(card, allCards, currentIndex) {
    if (currentIndex > 0) {
      const prevCard = allCards[currentIndex - 1];
      prevCard.parentNode.insertBefore(card, prevCard);
      card.focus();
      this.saveCardOrder();
      this.announceToScreenReader(`Moved to position ${currentIndex}`);
    } else {
      this.announceToScreenReader('Already at the beginning');
    }
  }

  /**
   * Move card down (toward end of list)
   */
  moveCardDown(card, allCards, currentIndex) {
    if (currentIndex < allCards.length - 1) {
      const nextCard = allCards[currentIndex + 1];
      nextCard.parentNode.insertBefore(card, nextCard.nextSibling);
      card.focus();
      this.saveCardOrder();
      this.announceToScreenReader(`Moved to position ${currentIndex + 2}`);
    } else {
      this.announceToScreenReader('Already at the end');
    }
  }

  /**
   * Focus previous card in list
   */
  focusPreviousCard(allCards, currentIndex) {
    if (currentIndex > 0) {
      allCards[currentIndex - 1].focus();
    }
  }

  /**
   * Focus next card in list
   */
  focusNextCard(allCards, currentIndex) {
    if (currentIndex < allCards.length - 1) {
      allCards[currentIndex + 1].focus();
    }
  }

  /**
   * Announce message to screen readers via live region
   */
  announceToScreenReader(message) {
    // Find or create live region
    let liveRegion = document.getElementById('es-live-region');
    if (!liveRegion) {
      liveRegion = document.createElement('div');
      liveRegion.id = 'es-live-region';
      liveRegion.setAttribute('aria-live', 'polite');
      liveRegion.setAttribute('aria-atomic', 'true');
      liveRegion.className = 'sr-only';
      liveRegion.style.cssText = 'position: absolute; left: -10000px; width: 1px; height: 1px; overflow: hidden;';
      document.body.appendChild(liveRegion);
    }
    
    // Clear and set message (triggers announcement)
    liveRegion.textContent = '';
    setTimeout(() => {
      liveRegion.textContent = message;
    }, 100);
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
