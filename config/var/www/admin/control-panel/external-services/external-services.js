// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v={ES_DASHBOARD_VER}';
import { SERVICE_DEFINITIONS } from './services-config.js?v={ES_DASHBOARD_VER}';
import { readCookie, writeCookie, sanitizeFaIconClass, sanitizeFaIconSuffix } from './external-services-utils.js?v={ES_DASHBOARD_VER}';
import { attachExternalServicesInteractionMethods } from './external-services-interactions.js?v={ES_DASHBOARD_VER}';

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

// Accepts FA short style prefixes: fas, far, fab, fal, fad, fat.
// Note: `fat` (thin) is a Font Awesome 6+ style; ensure the loaded FA version supports it.
const FA_STYLE_PREFIX_SHORT_PATTERN = /^fa[rsbdlt]$/; // Includes `fat` (thin), which requires Font Awesome 6+.
const FA_STYLE_PREFIX_LONG_PATTERN = /^fa-(solid|regular|brands|light|duotone|thin)$/;
const FA_ICON_MODIFIER_PATTERN = /^fa-(?:spin|pulse|fw|lg|xs|sm|1x|2x|3x|4x|5x|6x|7x|8x|9x|10x)$/;

const ERROR_LOADING_EXTERNAL_SERVICES_MESSAGE = "Failed to fetch external service status. Check your internet connection and refresh the page. If the problem continues, check the browser console for details or contact your administrator.";
const SETTINGS_INSTRUCTION_TEXT = 'Toggle services to show/hide on the dashboard. Drag service cards to reorder them, or use the keyboard: press Enter to activate reorder mode and use arrow keys to move cards. Click "Save Changes" to apply. Services are organized by category.';
const DEFAULT_ICON_SUFFIX = 'question';

const SERVICE_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const SERVICE_CACHE_MAX_SIZE = 100; // Limit cache size to prevent memory growth

const DEFAULT_NOTIFICATION_DURATION_MS = 3000;
const DEFAULT_NOTIFICATION_ANIMATION_DURATION_MS = 300;
const DEFAULT_NOTIFICATION_SLIDE_OUT_ANIMATION_NAME = 'slide-out';
const DEFAULT_REQUEST_TIMEOUT_MS = 60000;
const DEFAULT_LIVE_REGION_ANNOUNCEMENT_DELAY_MS = 100;

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

    // State management with TTL cache and LRU eviction (configured by SERVICE_CACHE_TTL_MS and SERVICE_CACHE_MAX_SIZE)
    // serviceCache entries are stored as: { data: Object, timestamp: number }
    this.serviceCache = new Map();
    this.cacheTTL = SERVICE_CACHE_TTL_MS;
    this.cacheMaxSize = SERVICE_CACHE_MAX_SIZE;
    this.initialized = false; // Track if services have been loaded (lazy loading)

    // Limits concurrent requests to prevent overwhelming the server/browser
    this.maxConcurrentRequests = 6;
    this.activeRequests = 0;
    this.requestQueue = [];
    // Stores in-flight Promises keyed by serviceKey to deduplicate concurrent requests for the same service.
    this.inFlightRequests = {};

    // Notification timing configuration
    this.notificationDurationMs = DEFAULT_NOTIFICATION_DURATION_MS;
    this.notificationAnimationDurationMs = DEFAULT_NOTIFICATION_ANIMATION_DURATION_MS;
    this.notificationSlideOutAnimationName = DEFAULT_NOTIFICATION_SLIDE_OUT_ANIMATION_NAME;
    this.requestTimeoutMs = DEFAULT_REQUEST_TIMEOUT_MS;
    this.liveRegionAnnouncementDelayMs = DEFAULT_LIVE_REGION_ANNOUNCEMENT_DELAY_MS;

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

    try {
      await this.loadExternalServices();
      this.initialized = true;
    } catch (error) {
      this.initialized = false;
      throw error;
    }
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
    return this._renderServices(true);
  }

  /**
   * Refresh the services display without full re-initialization
   * Updates visible cards using current preferences without clearing cache or re-fetching settings panel
   * @returns {Promise<void>}
   */
  async refreshServicesDisplay() {
    return this._renderServices(false);
  }

  /**
   * Internal method to render services with minimal code duplication
   * @param {boolean} isFullLoad - Whether to render settings as well
   * @returns {Promise<void>}
   * @private
   */
  async _renderServices(isFullLoad) {
    try {
      this.container.replaceChildren();

      const serviceDefinitions = this.getServiceDefinitions();
      const preferences = this.loadServicePreferences() || {};
      const services = this.createAllServicesEnabledMap(serviceDefinitions);

      if (isFullLoad) {
        this.renderServiceSettings(this.settingsContainer, services, serviceDefinitions, preferences);
      }

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
      console.error(`Failed to ${isFullLoad ? 'load' : 'refresh'} external services:`, error);
      this.renderErrorState();
    }
  }

  /**
   * Create a new map with all services enabled from definitions
   * @param {Object} serviceDefinitions - Map of service keys to definition objects
   * @returns {Object} New services object with all keys set to true
   */
  createAllServicesEnabledMap(serviceDefinitions) {
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
    p.textContent = ERROR_LOADING_EXTERNAL_SERVICES_MESSAGE;

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
   * Determine whether a service should be rendered as a static card
   * @param {Object} serviceDef - Service definition object
   * @returns {boolean} True when service has no dynamic status source
   */
  isStaticService(serviceDef) {
    return !serviceDef.useFeed && !serviceDef.corsEnabled && !serviceDef.api;
  }

  /**
   * Render service cards within a category container
   * @param {HTMLElement} container - Category container element
   * @param {Array<{key: string, def: Object}>} services - Array of service key/definition pairs
   * @returns {void}
   */
  renderCategoryCards(container, services) {
    for (const { key: serviceKey, def: serviceDef } of services) {
      if (this.isStaticService(serviceDef)) {
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
    return this.createAllServicesEnabledMap(this.getServiceDefinitions());
  }

  /**
   * Fetch available services from API
   * @returns {Promise<Object>} Services object with keys mapped to enabled state
   */
  async fetchAvailableServices() {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    try {
      const response = await fetch("/api/external-services/config", {
        credentials: 'include',
        signal: controller.signal
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const expectedOrigin = window.location.origin;
      const responseOrigin = new URL(response.url, window.location.href).origin;
      if (responseOrigin !== expectedOrigin) {
        throw new Error(`Unexpected response origin: ${responseOrigin}`);
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
    } finally {
      clearTimeout(timeoutId);
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

    // Track pending changes as instance state (shared across components)
    this.pendingChanges = {};

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
        category, categories[category], services, serviceDefinitions, preferences, this.pendingChanges
      );
      settingsContent.appendChild(categorySection);
    }

    // Create and append save button
    const saveButton = this.createSaveButton(settingsContent, services, this.pendingChanges);
    settingsContent.appendChild(saveButton);
  }

  /**
   * Create settings panel structure (toggle button and content container)
   * @returns {{settingsToggle: HTMLButtonElement, settingsContent: HTMLElement}} Settings UI elements
   */
  createSettingsStructure() {
    const settingsToggle = document.createElement("button");
    settingsToggle.className = "settings-toggle-btn";
    settingsToggle.setAttribute("aria-label", "Service Settings");

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
    headerP.textContent = SETTINGS_INSTRUCTION_TEXT;
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
    if (!toggleBtn) {
      console.error(`Toggle control is unavailable for category: ${category}.`, {
        category,
        missingElement: ".category-toggle-all-btn",
        component: "ExternalServicesManager.createSettingsCategorySection"
      });
      return categorySection;
    }
    const areAllCategoryServicesEnabled = () => categoryCheckboxes.every(cb => cb.checked);
    const toggleTextEl = toggleBtn.querySelector(".toggle-all-text");
    if (!toggleTextEl) {
      console.error(`Failed to find toggle button text element for category: ${category}`);
      return categorySection;
    }
    const updateToggleButtonState = () => {
      const allEnabled = areAllCategoryServicesEnabled();
      const actionText = allEnabled ? "Disable All" : "Enable All";
      const actionAria = allEnabled
        ? `Disable all ${category} services`
        : `Enable all ${category} services`;

      toggleTextEl.textContent = actionText;
      toggleBtn.setAttribute("aria-label", actionAria);
    };

    updateToggleButtonState();

    toggleBtn.addEventListener("click", () => {
      const allEnabled = areAllCategoryServicesEnabled();
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
    saveButton.setAttribute("aria-label", "Save Changes");

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
   * Updates the save button's rendered content by replacing both its icon and label text.
   * Use this method for non-default/transient UI states (for example: saving, saved, or error feedback)
   * when the button should communicate progress or result to the user.
   * Use `resetSaveButtonContent` when returning the button to its default idle "Save Changes" state.
   *
   * @param {HTMLElement} saveButton - Save button element to update.
   * @param {string} iconClass - Full icon class string to apply to the `<i>` element (for example, "fas fa-save").
   * @param {string} text - Visible button label text to render after the icon.
   */
  setSaveButtonContent(saveButton, iconClass, text) {
    saveButton.textContent = "";

    const icon = document.createElement("i");
    icon.className = iconClass;
    icon.setAttribute("aria-hidden", "true");
    saveButton.appendChild(icon);
    saveButton.appendChild(document.createTextNode(` ${text}`));
  }

  /**
   * Determines whether an error corresponds to storage quota exhaustion.
   * @param {Error|DOMException|Object} error - Error thrown while writing to storage.
   * @returns {boolean}
   */
  isQuotaExceededError(error) {
    return !!error && (
      error.name === 'QuotaExceededError' ||
      error.name === 'NS_ERROR_DOM_QUOTA_REACHED' ||
      error.code === 22 ||
      error.code === 1014
    );
  }

  /**
   * Validate browser storage availability for preferences persistence
   * @returns {Storage}
   * @throws {Error} If browser storage is unavailable or disabled
   */
  validateStorageAvailability() {
    const storageTestKey = '__servicePreferences_storage_test__';
    const storage = globalThis.localStorage;
    if (!storage || typeof storage.setItem !== 'function' || typeof storage.removeItem !== 'function') {
      throw new Error('Unable to save preferences: browser storage is disabled or unavailable.');
    }

    try {
      storage.setItem(storageTestKey, '1');
      storage.removeItem(storageTestKey);
    } catch (availabilityError) {
      console.error('localStorage availability check failed:', availabilityError);
      throw new Error('Unable to save preferences: browser storage is disabled or unavailable.');
    }
    return storage;
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
      this.setSaveButtonContent(saveButton, "fas fa-spinner fa-spin", " Saving...");

      const safeChanges = this.getAllowedPreferenceChanges(pendingChanges);

      // Load and update preferences
      const storedPreferences = this.loadServicePreferences() || {};
      const currentPreferences = this.getAllowedPreferenceChanges(storedPreferences);
      this.applyPreferenceChanges(currentPreferences, safeChanges);

      // Save preferences to local storage (avoid tamper-prone cookie storage)
      const storage = this.validateStorageAvailability();

      try {
        storage.setItem('servicePreferences', JSON.stringify(currentPreferences));
      } catch (storageError) {
        if (this.isQuotaExceededError(storageError)) {
          throw new Error('Unable to save preferences: browser storage is full.');
        }
        throw new Error('Unable to save preferences: browser storage is unavailable or disabled.');
      }
      this.applyPreferenceChanges(services, safeChanges);

      // Clear pending changes
      for (const key of Object.keys(pendingChanges)) {
        delete pendingChanges[key];
      }

      // Show success state
      this.setSaveButtonContent(saveButton, "fas fa-check", " Saved!");

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
      this.setSaveButtonContent(saveButton, "fas fa-times", " Save Failed");
      saveButton.disabled = false;

      setTimeout(() => {
        this.resetSaveButtonContent(saveButton);
      }, 2000);

      this.showNotification(error?.message || 'Failed to save preferences', 'error');
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
   * Supports explicit style prefixes in the input (for example: "fab fa-github").
   * @param {string} iconSuffix - Icon suffix or class list (for example: "spinner", "fa-spinner fa-spin", "far fa-clock")
   * @param {string|null} fallbackSuffix - Optional fallback icon suffix/class list
   * @returns {string} Sanitized class string (for example: "fas fa-spinner")
   */
  buildFaIconClass(iconSuffix, fallbackSuffix = null) {
    const parseIconInput = (value) => {
      if (typeof value !== "string" || !value.trim()) {
        return { stylePrefix: null, iconName: null };
      }

      const parts = value.trim().split(/\s+/);
      let stylePrefix = null;
      let iconName = null;

      for (const part of parts) {
        // Accept only recognized FontAwesome style-prefix tokens (see pattern constants).
        if (FA_STYLE_PREFIX_SHORT_PATTERN.test(part) || FA_STYLE_PREFIX_LONG_PATTERN.test(part)) {
          stylePrefix = part;
          continue;
        }

        if (!iconName && part.startsWith('fa-') && /^fa-[a-z0-9-]+$/.test(part) && !part.includes('--') && !part.endsWith('-') && !FA_ICON_MODIFIER_PATTERN.test(part)) {
          iconName = part;
        }
      }

      if (!iconName) {
        const iconCandidates = parts.filter((part) =>
          !FA_STYLE_PREFIX_SHORT_PATTERN.test(part) &&
          !FA_STYLE_PREFIX_LONG_PATTERN.test(part) &&
          !FA_ICON_MODIFIER_PATTERN.test(part)
        );
        iconName = sanitizeFaIconSuffix(iconCandidates.length ? iconCandidates[iconCandidates.length - 1] : "");
      }

      return { stylePrefix, iconName };
    };

    const primary = parseIconInput(iconSuffix);
    const fallback = parseIconInput(fallbackSuffix);

    const selected = primary.iconName ? primary : (fallback.iconName ? fallback : null);
    const stylePrefix = selected ? (selected.stylePrefix || "fas") : "fas";
    const safeSuffix = selected ? selected.iconName : DEFAULT_ICON_SUFFIX;

    return sanitizeFaIconClass(`${stylePrefix} fa-${safeSuffix}`);
  }

  /**
   * Create service card header (icon + info)
   * @param {Object} serviceDef - Service definition
   * @param {string} statusClassName - CSS class for status
   * @param {string} statusIconClass - FontAwesome icon identifier; accepts either an icon suffix (e.g., 'spinner', 'check-circle') or a full class string (e.g., 'fas fa-spinner fa-spin')
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
   * @param {string} statusIconSuffix - FontAwesome icon name (accepts both `check-circle` and `fa-check-circle` formats)
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
      iconElement.className = this.buildFaIconClass(statusIconSuffix);
      statusSpan.appendChild(iconElement);
      const safeStatusText = statusDescription == null ? '' : String(statusDescription);
      statusSpan.appendChild(document.createTextNode(` ${safeStatusText}`));
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
      // Reuse existing in-flight request for this serviceKey to avoid duplicate fetches
      if (!this.inFlightRequests[serviceKey]) {
        this.inFlightRequests[serviceKey] = this.queueRequest(async () => {
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

      try {
        data = await this.inFlightRequests[serviceKey];
      } finally {
        delete this.inFlightRequests[serviceKey];
      }
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
      console.error(`Service card not found: ${name}. Status updates will be skipped.`);
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
          credentials: 'same-origin'
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
   * Implements LRU cache with configured max size (`this.cacheMaxSize`)
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
    // Try to load from local storage
    let storedPrefs = null;
    try {
      storedPrefs = globalThis.localStorage.getItem('servicePreferences');
    } catch (storageError) {
      console.error('Failed to access localStorage for service preferences:', storageError);
      return null;
    }

    if (!storedPrefs) {
      // Return null if no valid preferences found - will use defaults
      return null;
    }

    try {
      const parsed = JSON.parse(storedPrefs);
      // Validate it's an object with expected structure
      if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
        return parsed;
      }
    } catch (parseError) {
      console.error('Failed to parse stored preferences:', parseError);
      console.warn('Corrupted service preferences detected; resetting stored preferences to defaults.');
      // Clear invalid entry
      try {
        globalThis.localStorage.removeItem('servicePreferences');
      } catch (removeError) {
        console.error('Failed to clear invalid stored preferences:', removeError);
      }
    }

    // Return null if no valid preferences found - will use defaults
    return null;
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
        console.error('Failed to parse service order, falling back to default order:', e);
      }
    }
    // Build default order dynamically from SERVICE_DEFINITIONS to avoid drift.
    if (!SERVICE_DEFINITIONS || typeof SERVICE_DEFINITIONS !== 'object') {
      console.error('SERVICE_DEFINITIONS is unavailable or invalid; cannot build default service order.');
      return [];
    }

    const servicesByCategory = new Map();
    const serviceKeys = Object.keys(SERVICE_DEFINITIONS);

    serviceKeys.forEach((key) => {
      const definition = SERVICE_DEFINITIONS[key] || {};
      const rawCategory = definition.category;
      const trimmedCategory = typeof rawCategory === 'string' ? rawCategory.trim() : '';
      const category = trimmedCategory || 'Uncategorized';

      if (!servicesByCategory.has(category)) {
        servicesByCategory.set(category, []);
      }
      servicesByCategory.get(category).push(key);
    });

    const ordered = [];
    const compareServiceKeys = (a, b) => a.localeCompare(b);

    // First: known categories in configured display order.
    CATEGORY_ORDER.forEach((category) => {
      const keys = servicesByCategory.get(category);
      if (keys && keys.length > 0) {
        ordered.push(...keys.sort(compareServiceKeys));
        servicesByCategory.delete(category);
      }
    });

    // Then: any categories not listed in CATEGORY_ORDER.
    Array.from(servicesByCategory.keys())
      .sort((a, b) => a.localeCompare(b))
      .forEach((category) => {
        const keys = servicesByCategory.get(category) || [];
        ordered.push(...keys.sort(compareServiceKeys));
      });

    return ordered;
  }

  /**
   * Save service order to cookie
   * @param {string[]} orderArray - Array of service keys in desired order
   * @returns {void}
   */
  saveServiceOrder(orderArray) {
    writeCookie('serviceOrder', encodeURIComponent(JSON.stringify(orderArray)), 365);
  }
}

attachExternalServicesInteractionMethods(ExternalServicesManager);
