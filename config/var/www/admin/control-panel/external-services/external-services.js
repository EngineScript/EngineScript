// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v={ES_DASHBOARD_VER}';
import { SERVICE_DEFINITIONS } from './services-config.js?v={ES_DASHBOARD_VER}';
import { readCookie, writeCookie, removeCookie, sanitizeFaIconClass, sanitizeFaIconSuffix } from './external-services-utils.js?v={ES_DASHBOARD_VER}';

const CATEGORY_ORDER = [
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

const DEFAULT_ICON_SUFFIX = 'question';

export class ExternalServicesManager {
  /**
   * Create an ExternalServicesManager instance
   * @param {string} containerSelector - CSS selector for the services container
   * @param {string} settingsContainerSelector - CSS selector for the settings container
   */
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
    
    // Notification timing configuration
    this.notificationDurationMs = 3000;
    this.notificationAnimationDurationMs = 300;
    this.notificationSlideOutAnimationName = 'slide-out';
    this.requestTimeoutMs = 60000;
    this.liveRegionAnnouncementDelayMs = 100;
    
    // Keyboard navigation state for accessibility
    this.reorderMode = false;
    this.selectedCard = null;
    this.keyboardHandler = null;
    this.liveRegion = null;
  }

  /**
   * Initialize the external services manager (lazy loading)
   * Only loads when user navigates to external services page
   * @returns {Promise<void>}
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
   * Main method to load and display all external services.
   * This method is a top-level UI orchestration boundary: DOM/rendering and
   * service-processing steps may throw. Errors are caught here so they are logged
   * once and the UI can transition to renderErrorState instead of leaving a
   * partially rendered dashboard.
   * @returns {Promise<void>}
   */
  async loadExternalServices() {
    try {
      this.container.replaceChildren();

      // Get service definitions and preferences
      const serviceDefinitions = this.getServiceDefinitions();
      const preferences = this.loadServicePreferences() || {};
      const services = this.buildServicesObject(serviceDefinitions);

      // Render settings panel
      this.renderServiceSettings(this.settingsContainer, services, serviceDefinitions, preferences);

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
   * Refresh the services display without full re-initialization
   * Updates visible cards using current preferences without clearing cache or re-fetching settings panel
   * @returns {Promise<void>}
   */
  async refreshServicesDisplay() {
    try {
      this.container.replaceChildren();

      const serviceDefinitions = this.getServiceDefinitions();
      const preferences = this.loadServicePreferences() || {};
      const services = this.buildServicesObject(serviceDefinitions);

      const orderedServiceKeys = this.getOrderedServiceKeys(services);
      const enabledServices = this.filterEnabledServices(orderedServiceKeys, serviceDefinitions, preferences);

      if (enabledServices.length === 0) {
        this.renderEmptyState();
        return;
      }

      const servicesByCategory = this.groupServicesByCategory(orderedServiceKeys, serviceDefinitions, preferences);
      this.renderServiceCategories(servicesByCategory);

      this.enableServiceDragDrop(this.container);
    } catch (error) {
      console.error('Failed to refresh services display:', error);
      this.renderErrorState();
    }
  }

  /**
   * Build services object from definitions
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @returns {Object} Services object with all keys set to true
   */
  buildServicesObject(serviceDefinitions) {
    return Object.fromEntries(Object.keys(serviceDefinitions).map(key => [key, true]));
  }

  /**
   * Get service keys in custom order, adding any new services
   * @param {Object} services - Services object keyed by service identifier
   * @returns {string[]} Ordered array of service keys
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
   * @param {string[]} orderedServiceKeys - Ordered array of service keys
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @param {Object} preferences - User preferences with service keys mapped to booleans
   * @returns {string[]} Filtered array of enabled service keys
   */
  filterEnabledServices(orderedServiceKeys, serviceDefinitions, preferences) {
    return orderedServiceKeys.filter(key => {
      return serviceDefinitions[key] && preferences[key] === true;
    });
  }

  /**
   * Render empty state when no services are enabled
   * @returns {void}
   */
  renderEmptyState() {
    const emptyState = document.createElement("div");
    emptyState.className = "empty-state";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = "empty-state-icon";
    const icon = document.createElement("i");
    icon.className = "fas fa-toggle-off";
    icon.setAttribute("aria-hidden", "true");
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
   * @returns {void}
   */
  renderErrorState() {
    this.container.replaceChildren();
    
    const errorDiv = document.createElement("div");
    errorDiv.className = "error-state";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = "error-icon";
    const icon = document.createElement("i");
    icon.className = "fas fa-exclamation-circle";
    icon.setAttribute("aria-hidden", "true");
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
   * @param {string[]} orderedServiceKeys - Ordered array of service keys
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @param {Object} preferences - User preferences with service keys mapped to booleans
   * @returns {Object} Services grouped by category name
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
   * @param {Object} servicesByCategory - Services grouped by category name
   * @returns {void}
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
   * @param {string} category - Category name
   * @returns {HTMLElement} Category header div element
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
   * @param {string} category - Category name
   * @returns {HTMLElement} Category grid container element
   */
  createCategoryContainer(category) {
    const categoryContainer = document.createElement("div");
    categoryContainer.className = "service-category-grid";
    categoryContainer.dataset.category = category;
    categoryContainer.setAttribute("role", "list");
    categoryContainer.setAttribute("aria-label", `${category} services`);
    return categoryContainer;
  }

  /**
   * Render service cards within a category container
   * @param {HTMLElement} container - Category container element
   * @param {Array<{key: string, def: Object}>} services - Array of service key/definition pairs
   * @returns {void}
   */
  renderCategoryCards(container, services) {
    for (const { key: serviceKey, def: serviceDef } of services) {
      if (!serviceDef.useFeed && !serviceDef.corsEnabled && !serviceDef.api) {
        // Render static card immediately (e.g., AWS)
        this.renderStaticServiceCard(container, serviceKey, serviceDef);
      } else {
        // Render card with loading state, then fetch status
        this.renderServiceCardLoadingState(container, serviceKey, serviceDef);
        this.fetchServiceStatus(serviceKey, serviceDef);
      }
    }
  }

  /**
   * Fetch service status (non-blocking)
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @returns {void}
   */
  fetchServiceStatus(serviceKey, serviceDef) {
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
   * Build a map with all configured services enabled
   * @returns {Object} Services object with every known key set to true
   */
  buildAllServicesEnabledMap() {
    const serviceDefinitions = this.getServiceDefinitions();
    const services = {};
    Object.keys(serviceDefinitions).forEach(key => {
      services[key] = true;
    });
    return services;
  }

  /**
   * Fetch available services from API
   * @returns {Promise<Object>} Services object with keys mapped to enabled state
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
        services = this.buildAllServicesEnabledMap();
      }
      
      return services;
    } catch (error) {
      console.error('Failed to fetch services config:', error);
      // Fallback: return all services enabled
      return this.buildAllServicesEnabledMap();
    }
  }

  /**
   * Get service definitions for all supported external services
   * @returns {Object} SERVICE_DEFINITIONS object from services-config
   */
  getServiceDefinitions() {
    return SERVICE_DEFINITIONS;
  }

  /**
   * Render the service settings panel with toggles
   * @param {HTMLElement} settingsContainer - Container element for settings panel
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @param {Object} preferences - User preference overrides keyed by service identifier
   * @returns {void}
   */
  renderServiceSettings(settingsContainer, services, serviceDefinitions, preferences) {
    settingsContainer.replaceChildren();
    
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
        category, categories[category], services, serviceDefinitions, preferences, pendingChanges
      );
      settingsContent.appendChild(categorySection);
    }

    // Create and append save button
    const saveButton = this.createSaveButton(settingsContent, services, pendingChanges);
    settingsContent.appendChild(saveButton);
  }

  /**
   * Create settings panel structure (toggle button and content container)
   * @returns {{settingsToggle: HTMLButtonElement, settingsContent: HTMLElement}} Settings UI elements
   */
  createSettingsStructure() {
    const settingsToggle = document.createElement("button");
    settingsToggle.className = "settings-toggle-btn";
    
    const cogIcon = document.createElement("i");
    cogIcon.className = "fas fa-cog";
    cogIcon.setAttribute("aria-hidden", "true");
    const textSpan = document.createElement("span");
    textSpan.textContent = "Service Settings";
    const chevronIcon = document.createElement("i");
    chevronIcon.className = "fas fa-chevron-down toggle-icon";
    chevronIcon.setAttribute("aria-hidden", "true");
    
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
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @returns {Object} Services grouped by category name
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
   * @returns {string[]} Array of category names in display order
   */
  getCategoryOrder() {
    return [...CATEGORY_ORDER];
  }

  /**
   * Create a category section for settings panel
   * @param {string} category - Category name
   * @param {string[]} serviceKeys - Array of service keys in this category
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @param {Object} preferences - User preference overrides keyed by service identifier
   * @param {Object} pendingChanges - Mutable object tracking unsaved toggle changes
   * @returns {HTMLElement} Category section element
   */
  createSettingsCategorySection(category, serviceKeys, services, serviceDefinitions, preferences, pendingChanges) {
    const categorySection = document.createElement("div");
    categorySection.className = "category-section";

    // Create header with toggle all button
    const categoryHeader = this.createSettingsCategoryHeader(category);
    categorySection.appendChild(categoryHeader);

    // Create services grid with checkboxes
    const { servicesGrid, categoryCheckboxes } = this.createServicesGrid(
      serviceKeys, services, preferences, serviceDefinitions, pendingChanges
    );
    categorySection.appendChild(servicesGrid);

    // Wire up toggle all button
    const toggleBtn = categoryHeader.querySelector(".category-toggle-all-btn");
    const updateToggleButtonState = () => {
      const allEnabled = categoryCheckboxes.every(cb => cb.checked);
      const actionText = allEnabled ? "Disable All" : "Enable All";
      const actionAria = allEnabled
        ? `Disable all ${category} services`
        : `Enable all ${category} services`;

      const toggleTextEl = toggleBtn.querySelector(".toggle-all-text");
      if (toggleTextEl) {
        toggleTextEl.textContent = actionText;
      }
      toggleBtn.setAttribute("aria-label", actionAria);
    };

    updateToggleButtonState();

    toggleBtn.addEventListener("click", () => {
      const allEnabled = categoryCheckboxes.every(cb => cb.checked);
      categoryCheckboxes.forEach(cb => {
        cb.checked = !allEnabled;
        cb.dispatchEvent(new Event('change'));
      });
      updateToggleButtonState();
    });

    return categorySection;
  }

  /**
   * Create category header with toggle all button
   * @param {string} category - Category name
   * @returns {HTMLElement} Category header element with toggle button
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
    toggleAllBtn.setAttribute("aria-label", `Enable all ${category} services`);
    
    const toggleText = document.createElement("span");
    toggleText.className = "toggle-all-text";
    toggleText.textContent = "Enable All";
    toggleAllBtn.appendChild(toggleText);
    
    const toggleIcon = document.createElement("i");
    toggleIcon.className = "fas fa-toggle-on";
    toggleIcon.setAttribute("aria-hidden", "true");
    toggleAllBtn.appendChild(toggleIcon);
    
    categoryHeader.appendChild(toggleAllBtn);
    return categoryHeader;
  }

  /**
   * Create services grid with checkboxes for each service
   * @param {string[]} serviceKeys - Array of service keys
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} preferences - User preference overrides keyed by service identifier
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @param {Object} pendingChanges - Mutable object tracking unsaved toggle changes
   * @returns {{servicesGrid: HTMLElement, categoryCheckboxes: HTMLInputElement[]}} Grid element and checkbox references
   */
  createServicesGrid(serviceKeys, services, preferences, serviceDefinitions, pendingChanges) {
    const servicesGrid = document.createElement("div");
    servicesGrid.className = "services-grid";
    const categoryCheckboxes = [];
    
    serviceKeys.forEach(serviceKey => {
      const serviceDef = serviceDefinitions[serviceKey];
      const hasPreference = preferences && Object.prototype.hasOwnProperty.call(preferences, serviceKey);
      const isEnabled = hasPreference ? preferences[serviceKey] : services[serviceKey];
      
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
   * @param {HTMLElement} settingsContent - Settings content container element
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} pendingChanges - Mutable object tracking unsaved toggle changes
   * @returns {HTMLElement} Save button element
   */
  createSaveButton(settingsContent, services, pendingChanges) {
    const saveButton = document.createElement("button");
    saveButton.className = "settings-save-btn";
    
    const saveIcon = document.createElement("i");
    saveIcon.className = "fas fa-save";
    saveIcon.setAttribute("aria-hidden", "true");
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
   * @param {HTMLElement} saveButton - Save button element
   * @param {Object} services - Services object keyed by service identifier
   * @param {Object} pendingChanges - Mutable object tracking unsaved toggle changes
   * @returns {Promise<void>}
   */
  async handleSavePreferences(saveButton, services, pendingChanges) {
    try {
      saveButton.disabled = true;
      saveButton.textContent = '';
      const spinnerIcon = document.createElement("i");
      spinnerIcon.className = "fas fa-spinner fa-spin";
      saveButton.appendChild(spinnerIcon);
      saveButton.appendChild(document.createTextNode(" Saving..."));

      const safeChanges = this.getAllowedPreferenceChanges(pendingChanges);
      
      // Load and update preferences
      const storedPreferences = this.loadServicePreferences() || {};
      const currentPreferences = this.getAllowedPreferenceChanges(storedPreferences);
      this.applyPreferenceChanges(currentPreferences, safeChanges);
      
      // Save to cookie
      writeCookie('servicePreferences', encodeURIComponent(JSON.stringify(currentPreferences)), 365);
      this.applyPreferenceChanges(services, safeChanges);
      
      // Clear pending changes
      for (const key of Object.keys(pendingChanges)) {
        delete pendingChanges[key];
      }
      
      // Show success state
      saveButton.textContent = '';
      const checkIcon = document.createElement("i");
      checkIcon.className = "fas fa-check";
      saveButton.appendChild(checkIcon);
      saveButton.appendChild(document.createTextNode(" Saved!"));
      
      setTimeout(() => {
        this.resetSaveButtonContent(saveButton);
        saveButton.classList.remove('has-changes');
        saveButton.disabled = true;
      }, 2000);
      
      // Refresh visible services display without full re-initialization
      await this.refreshServicesDisplay();
      
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
        this.resetSaveButtonContent(saveButton);
      }, 2000);
      
      this.showNotification('Failed to save preferences', 'error');
    }
  }

  /**
   * Filter arbitrary preference objects to known service keys with boolean values.
   * @param {Object} changes - Source preference map
   * @returns {Object} Sanitized preference map
   */
  getAllowedPreferenceChanges(changes) {
    const allowedKeys = new Set(Object.keys(this.getServiceDefinitions()));
    const safeChanges = {};

    Object.entries(changes || {}).forEach(([key, value]) => {
      if (allowedKeys.has(key) && typeof value === 'boolean') {
        safeChanges[key] = value;
      }
    });

    return safeChanges;
  }

  /**
   * Apply already-sanitized preference changes to a target object.
   * @param {Object} target - Target preferences object
   * @param {Object} changes - Sanitized preference changes
   * @returns {void}
   */
  applyPreferenceChanges(target, changes) {
    Object.keys(changes).forEach((key) => {
      target[key] = changes[key];
    });
  }

  /**
   * Reset save button content to default 'Save Changes' state
   * @param {HTMLElement} saveButton - The save button element to reset
   */
  resetSaveButtonContent(saveButton) {
    saveButton.textContent = '';
    const saveIcon = document.createElement("i");
    saveIcon.className = "fas fa-save";
    saveButton.appendChild(saveIcon);
    saveButton.appendChild(document.createTextNode(" Save Changes"));
  }

  // ============ Card Creation Helpers ============

  /**
   * Build a canonical, sanitized FontAwesome class string.
   * @param {string} iconSuffix - Icon suffix (for example: "spinner" or "fa-spinner fa-spin")
   * @param {string|null} fallbackSuffix - Optional fallback icon suffix
   * @returns {string} Sanitized class string (for example: "fas fa-spinner")
   */
  buildFaIconClass(iconSuffix, fallbackSuffix = null) {
    let safeSuffix = sanitizeFaIconSuffix(iconSuffix);

    if (!safeSuffix && fallbackSuffix) {
      safeSuffix = sanitizeFaIconSuffix(fallbackSuffix);
    }

    if (!safeSuffix) {
      safeSuffix = DEFAULT_ICON_SUFFIX;
    }

    return `fas fa-${safeSuffix}`;
  }

  /**
   * Create service card header (icon + info)
   * @param {Object} serviceDef - Service definition
   * @param {string} statusClassName - CSS class for status
   * @param {string} statusIconClass - FontAwesome icon class (e.g., 'fa-spinner fa-spin')
   * @returns {HTMLElement} Header div element containing icon and status info
   */
  createServiceCardHeader(serviceDef, statusClassName, statusIconClass) {
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    
    // Use DOM methods instead of innerHTML for security
    const iconElement = document.createElement("i");
    iconElement.className = this.buildFaIconClass(serviceDef.icon, DEFAULT_ICON_SUFFIX);
    iconElement.setAttribute("aria-hidden", "true");
    iconDiv.appendChild(iconElement);
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h4 = document.createElement("h4");
    h4.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = `service-status ${statusClassName}`;
    
    // Create status icon using DOM methods instead of innerHTML
    const statusIcon = document.createElement("i");
    statusIcon.className = this.buildFaIconClass(statusIconClass, DEFAULT_ICON_SUFFIX);
    statusIcon.setAttribute("aria-hidden", "true");
    statusSpan.appendChild(statusIcon);
    statusSpan.appendChild(document.createTextNode(" ")); // Add space after icon
    
    infoDiv.appendChild(h4);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    
    return headerDiv;
  }

  /**
   * Create base service card element
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @param {string} cardClass - CSS class for the card state
   * @param {HTMLElement} headerElement - Pre-built header element
   * @returns {HTMLElement} Anchor element styled as a service card
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
   * Render static service card (no API/feed)
   * @param {HTMLElement} container - Parent container to append the card to
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @returns {void}
   */
  renderStaticServiceCard(container, serviceKey, serviceDef) {
    const statusIconSuffix = "external-link-alt";
    const contentNode = document.createTextNode(serviceDef.statusText || 'Visit status page');
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-info", statusIconSuffix);
    const statusSpan = headerDiv.querySelector(".service-status");
    statusSpan.appendChild(contentNode);
    
    const serviceLink = this.createBaseServiceCard(serviceKey, serviceDef, "static", headerDiv);
    // Add success status class for green border like operational services
    serviceLink.classList.add('status-success');
    container.appendChild(serviceLink);
  }

  /**
   * Render service card with loading state
   * @param {HTMLElement} container - Parent container to append the card to
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @returns {void}
   */
  renderServiceCardLoadingState(container, serviceKey, serviceDef) {
    const statusIconSuffix = "spinner";
    const contentNode = document.createTextNode("Loading...");
    const headerDiv = this.createServiceCardHeader(serviceDef, "status-loading", statusIconSuffix);
    const iconElement = headerDiv.querySelector(".service-status i");
    if (iconElement) {
      iconElement.classList.add("fa-spin");
    }
    const statusSpan = headerDiv.querySelector(".service-status");
    statusSpan.appendChild(contentNode);
    
    const serviceLink = this.createBaseServiceCard(serviceKey, serviceDef, "loading", headerDiv);
    container.appendChild(serviceLink);
  }

  // ============ Status Update Helpers ============

  /**
   * Extract and determine status display values
   * @param {string} statusIndicator - Raw status indicator from API (e.g., 'none', 'minor', 'major')
   * @param {boolean} [isFeed=false] - Whether the status is from an Atom/RSS feed
   * @returns {{statusClass: string, statusIcon: string, statusColor: string}} Display values for rendering
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
   * @param {HTMLElement} serviceCard - Service card element to update
   * @param {string} statusDescription - Human-readable status text
   * @param {string} statusClass - CSS class name for the status
   * @param {string} statusIconSuffix - FontAwesome icon suffix (without fa- prefix)
   * @param {string} statusColor - Color category ('success', 'warning', or 'error')
   * @returns {void}
   */
  updateServiceCardStatus(serviceCard, statusDescription, statusClass, statusIconSuffix, statusColor) {
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
      // Use suffix sanitizer here because class is constructed as `fas fa-${suffix}`
      const safeIconSuffix = sanitizeFaIconSuffix(statusIconSuffix) || DEFAULT_ICON_SUFFIX;
      iconElement.className = `fas fa-${safeIconSuffix}`;
      statusSpan.appendChild(iconElement);
      statusSpan.appendChild(document.createTextNode(` ${this.utils.sanitizeInput(statusDescription)}`));
    }

    // Add card-level status class for visual emphasis
    serviceCard.classList.add(`status-${statusColor}`);
  }

  /**
   * Queue a request with concurrency limiting
   * Prevents overwhelming browser/server with too many concurrent requests
   * @param {Function} requestFn - Async function that performs the actual request
   * @returns {Promise} Resolves when request completes
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
   * @returns {void}
   */
  processQueue() {
    while (this.requestQueue.length > 0 && this.activeRequests < this.maxConcurrentRequests) {
      const nextRequest = this.requestQueue.shift();
      nextRequest();
    }
  }

  /**
   * Fetch data with timeout, caching support, and concurrency limiting
   * @param {Function} fetchFn - Function that accepts an AbortSignal and returns a fetch Promise
   * @param {string} serviceKey - Service identifier key for cache lookup
   * @returns {Promise<Object>} Promise resolving to service data (from cache or parsed JSON response)
   */
  async fetchServiceData(fetchFn, serviceKey) {
    // Check cache first - no need to queue if cached
    let data = this.getCachedService(serviceKey);
    
    if (!data) {
      // Not in cache, queue the fetch request with concurrency limiting
      data = await this.queueRequest(async () => {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.requestTimeoutMs);
        
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
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @returns {HTMLElement|null} Service card element or null if not found
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
   * Apply status data from API response to a service card
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @param {Object} data - API response data containing status
   * @returns {void}
   */
  applyStatusDataToCard(serviceKey, serviceDef, data) {
    const serviceCard = this.getServiceCardElement(serviceKey, serviceDef);
    if (!serviceCard) return;
    const isFeed = !!serviceDef.feedType;
    const { statusClass, statusIcon, statusColor } = this.getStatusDisplayValues(data.status.indicator, isFeed);
    this.updateServiceCardStatus(serviceCard, data.status.description, statusClass, statusIcon, statusColor);
  }

  /**
   * Update feed-based service status asynchronously
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object with feedType and optional feedFilter
   * @returns {Promise<void>}
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
      this.applyStatusDataToCard(serviceKey, serviceDef, data);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} feed status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Update StatusPage.io service status asynchronously
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object with api URL
   * @returns {Promise<void>}
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
      this.applyStatusDataToCard(serviceKey, serviceDef, data);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Handle service loading errors
   * @param {string} serviceKey - Service identifier key
   * @param {Object} serviceDef - Service definition object
   * @param {Error} error - The error that occurred
   * @returns {void}
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
   * @param {string} serviceKey - Service identifier key
   * @returns {Object|null} Cached data or null if expired/missing
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
   * @param {string} serviceKey - Service identifier key
   * @param {Object} data - Service data to cache
   * @returns {void}
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
   * @returns {void}
   */
  clearCache() {
    this.serviceCache.clear();
  }

  // ============ Cookie Management ============

  // ============ Service Preferences ============

  /**
   * Load service preferences from cookie
   * @returns {Object|null} Parsed preferences object or null if not found/invalid
   */
  loadServicePreferences() {
    try {
      // Try to load from cookie first
      const cookiePrefs = readCookie('servicePreferences');
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
          removeCookie('servicePreferences');
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
   * @returns {string[]} Array of service keys in display order
   */
  getServiceOrder() {
    const orderCookie = readCookie('serviceOrder');
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
   * @param {string[]} orderArray - Array of service keys in desired order
   * @returns {void}
   */
  saveServiceOrder(orderArray) {
    writeCookie('serviceOrder', encodeURIComponent(JSON.stringify(orderArray)), 365);
  }

  // ============ Drag and Drop ============

  /**
   * Enable drag-and-drop for service cards
   * @param {HTMLElement} container - Container element holding service cards
   * @returns {void}
   */
  enableServiceDragDrop(container) {
    const serviceCards = container.querySelectorAll('.external-service-card');
    let draggedElement = null;

    const reorderInstructionsId = 'external-services-reorder-instructions';
    let reorderInstructions = container.querySelector(`#${reorderInstructionsId}`);
    if (!reorderInstructions) {
      reorderInstructions = document.createElement('p');
      reorderInstructions.id = reorderInstructionsId;
      reorderInstructions.className = 'sr-only';
      reorderInstructions.textContent = 'To reorder services, press Enter on a card to enter reorder mode, then use arrow keys to move it.';
      container.insertBefore(reorderInstructions, container.firstChild);
    }

    serviceCards.forEach((card) => {
      card.draggable = true;
      
      // Add tabindex for keyboard accessibility
      card.setAttribute('tabindex', '0');
      card.setAttribute('role', 'listitem');
      const serviceName = card.dataset.serviceName || card.querySelector('h4')?.textContent || 'Service';
      card.setAttribute('aria-label', `${serviceName} (reorderable)`);
      card.setAttribute('aria-describedby', reorderInstructionsId);

      card.addEventListener('dragstart', (e) => {
        draggedElement = card;
        card.classList.add('dragging');
        if (e.dataTransfer) {
          e.dataTransfer.effectAllowed = 'move';
          // Use a minimal plain-text token instead of serializing HTML content.
          // Note: drop handling intentionally recalculates positions from the live DOM
          // (see drop listener below) for accuracy; this payload is set for DnD protocol
          // compliance/browser compatibility.
          e.dataTransfer.setData('text/plain', 'moving');
        }
      });

      card.addEventListener('dragover', (e) => {
        if (e.dataTransfer) {
          e.dataTransfer.dropEffect = 'move';
        }
        e.preventDefault();
        
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
          
          // Swap positions using current DOM order for accuracy at drop-time
          // (instead of trusting transferred index payload from dragstart).
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
   * @param {HTMLElement} container - Container element holding service cards
   * @returns {void}
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
   * @param {HTMLElement} card - Service card element to toggle reorder mode on
   * @param {string|null} serviceName - Optional service name for announcements
   * @returns {void}
   */
  toggleReorderMode(card, serviceName = null) {
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

      const announcementName =
        serviceName ||
        card.getAttribute('data-service-name') ||
        card.querySelector('h4')?.textContent ||
        'service';

      // Announce to screen readers
      this.announceToScreenReader(`Reorder mode. Use arrow keys to move ${announcementName}. Press Enter or Escape to exit.`);
      this.showNotification('Reorder mode: Use arrow keys to move, Enter/Escape to exit', 'info');
    }
  }

  /**
   * Exit reorder mode
   * @returns {void}
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
   * @param {HTMLElement} card - Service card element to move
   * @param {HTMLElement[]} allCards - Array of all service card elements
   * @param {number} currentIndex - Current position index of the card
   * @returns {void}
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
   * @param {HTMLElement} card - Service card element to move
   * @param {HTMLElement[]} allCards - Array of all service card elements
   * @param {number} currentIndex - Current position index of the card
   * @returns {void}
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
   * @param {HTMLElement[]} allCards - Array of all service card elements
   * @param {number} currentIndex - Current position index
   * @returns {void}
   */
  focusPreviousCard(allCards, currentIndex) {
    if (currentIndex > 0) {
      allCards[currentIndex - 1].focus();
    }
  }

  /**
   * Focus next card in list
   * @param {HTMLElement[]} allCards - Array of all service card elements
   * @param {number} currentIndex - Current position index
   * @returns {void}
   */
  focusNextCard(allCards, currentIndex) {
    if (currentIndex < allCards.length - 1) {
      allCards[currentIndex + 1].focus();
    }
  }

  /**
   * Announce message to screen readers via live region.
   * Uses a dedicated live region for accessibility announcements in this module.
   * @param {string} message - Message to announce
   * @returns {void}
   */
  announceToScreenReader(message) {
    if (!this.liveRegion) {
      this.liveRegion = document.createElement('div');
      this.liveRegion.id = 'es-live-region';
      this.liveRegion.setAttribute('aria-live', 'polite');
      this.liveRegion.setAttribute('aria-atomic', 'true');
      this.liveRegion.className = 'sr-only';
      document.body.appendChild(this.liveRegion);
    }
    
    // Clear and set message (triggers announcement)
    this.liveRegion.textContent = '';
    setTimeout(() => {
      this.liveRegion.textContent = message;
    }, this.liveRegionAnnouncementDelayMs);
  }

  /**
   * Save current card order to cookie
   * @returns {void}
   */
  saveCardOrder() {
    const cards = document.querySelectorAll('.external-service-card');
    const orderArray = Array.from(cards).map(card => card.dataset.serviceKey);
    this.saveServiceOrder(orderArray);
  }

  // ============ Notifications ============

  /**
   * Check whether a keyframes animation exists in currently loaded stylesheets.
   * @param {string} animationName - CSS keyframes name to look for
   * @returns {boolean}
   */
  hasAnimationKeyframes(animationName) {
    const styleSheets = Array.from(document.styleSheets || []);

    for (const styleSheet of styleSheets) {
      let rules;
      try {
        rules = styleSheet.cssRules || styleSheet.rules;
      } catch (e) {
        // Ignore cross-origin or otherwise inaccessible stylesheets.
        continue;
      }

      if (!rules) continue;

      const keyframesType = typeof CSSRule !== 'undefined' ? CSSRule.KEYFRAMES_RULE : 7;
      for (const rule of Array.from(rules)) {
        if (rule.type === keyframesType && rule.name === animationName) {
          return true;
        }
      }
    }

    return false;
  }

  /**
   * Schedule notification slide-out and removal.
   * Uses two-stage timing: display duration first, then animation duration before DOM removal.
   * @param {HTMLElement} notification - Notification element to remove
   * @returns {void}
   */
  scheduleNotificationRemoval(notification) {
    setTimeout(() => {
      if (this.hasAnimationKeyframes(this.notificationSlideOutAnimationName)) {
        notification.style.animation = `${this.notificationSlideOutAnimationName} ${this.notificationAnimationDurationMs / 1000}s ease`;
      }
      setTimeout(() => notification.remove(), this.notificationAnimationDurationMs);
    }, this.notificationDurationMs);
  }

  /**
   * Show notification to user
   * @param {string} message - Notification message text
   * @param {string} [type='info'] - Notification type ('info', 'success', or 'error')
   * @returns {void}
   */
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `es-notification notification-${type}`;
    notification.textContent = message;
    notification.setAttribute('role', 'status');
    notification.setAttribute('aria-live', 'polite');
    
    document.body.appendChild(notification);
    this.scheduleNotificationRemoval(notification);
  }
}
