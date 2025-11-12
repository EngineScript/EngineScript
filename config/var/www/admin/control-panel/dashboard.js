// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention

import { DashboardAPI } from './modules/api.js?v=2025.11.12.16';
import { DashboardState } from './modules/state.js?v=2025.11.12.16';
import { DashboardCharts } from './modules/charts.js?v=2025.11.12.16';
import { DashboardUtils } from './modules/utils.js?v=2025.11.12.16';

class EngineScriptDashboard {
  constructor() {
    // Initialize modules
    this.api = new DashboardAPI();
    this.state = new DashboardState();
    this.charts = new DashboardCharts();
    this.utils = new DashboardUtils();

    // Legacy property references for compatibility
    this.currentPage = this.state.currentPage;
    this.refreshInterval = this.state.refreshInterval;
    this.allowedTimeRanges = this.state.allowedTimeRanges;
    this.allowedPages = this.state.allowedPages;
    this.allowedTools = this.state.allowedTools;

    this.init();
  }

  init() {
    this.setupEventListeners();
    this.setupNavigation();
    this.startClock();
    this.api.loadCsrfToken(); // Load CSRF token before other API calls
    this.loadInitialData();
    this.hideLoadingScreen();
  }

  setupEventListeners() {
    // Mobile menu toggle
    const mobileMenuToggle = document.getElementById("mobile-menu-toggle");
    if (mobileMenuToggle) {
      mobileMenuToggle.addEventListener("click", () => this.toggleMobileMenu());
    }

    // Close mobile menu when clicking outside
    document.addEventListener("click", (e) => {
      const sidebar = document.querySelector(".sidebar");
      const mobileToggle = document.getElementById("mobile-menu-toggle");
      
      if (sidebar && sidebar.classList.contains("mobile-open") && 
          !sidebar.contains(e.target) && 
          !mobileToggle.contains(e.target)) {
        this.closeMobileMenu();
      }
    });

    // Navigation
    document.querySelectorAll(".nav-item").forEach((item) => {
      item.addEventListener("click", (e) => {
        e.preventDefault();
        const page = this.sanitizeInput(item.dataset.page);
        if (this.state.isValidPage(page)) {
          this.navigateToPage(page);
          // Close mobile menu after navigation
          this.closeMobileMenu();
        }
      });
    });

    // Refresh button
    const refreshBtn = document.getElementById("refresh-btn");
    if (refreshBtn) {
      refreshBtn.addEventListener("click", () => this.refreshData());
    }

    // Keyboard shortcuts
    this.setupKeyboardShortcuts();

    // File Manager tool card is now a direct HTML link
    // Status checking handled separately
  }
  setupNavigation() {
    // Set up single page app navigation
    const pages = document.querySelectorAll(".page-content");

    // Hide all pages except overview
    pages.forEach((page) => {
      if (page.id !== "overview-page") {
        page.style.display = "none";
      }
    });
  }

  navigateToPage(pageName) {
    // Validate page name
    if (!this.state.isValidPage(pageName)) {
      return;
    }

    // Update navigation
    document.querySelectorAll(".nav-item").forEach((item) => {
      item.classList.remove("active");
    });
    const targetNav = document.querySelector(`[data-page="${pageName}"]`);
    if (targetNav) {
      targetNav.classList.add("active");
    }

    // Update pages
    document.querySelectorAll(".page-content").forEach((page) => {
      page.style.display = "none";
    });
    const targetPage = document.getElementById(`${pageName}-page`);
    if (targetPage) {
      targetPage.style.display = "block";
      // Scroll to top when navigating to a new page
      targetPage.scrollTop = 0;
      // Also scroll the main content area to top
      const mainContent = document.querySelector(".main-content");
      if (mainContent) {
        mainContent.scrollTop = 0;
      }
    }

    // Update page title
    const pageTitle = document.getElementById("page-title");
    if (pageTitle) {
      pageTitle.textContent = this.getPageTitle(pageName);
    }

    // Load page-specific data
    this.loadPageData(pageName);
    this.state.setCurrentPage(pageName);
    this.currentPage = this.state.getCurrentPage();
  }

  getPageTitle(pageName) {
    return this.state.getPageTitle(pageName);
  }
    
  loadPageData(pageName) {
    // Validate page name
    if (!this.state.isValidPage(pageName)) {
      return;
    }

    switch (pageName) {
      case "overview":
        this.loadOverviewData();
        break;
      case "sites":
        this.loadSites();
        break;
      case "system":
        this.loadSystemInfo();
        break;
      case "external-services":
        this.loadExternalServices();
        break;
      case "tools":
        this.loadToolsData();
        break;
    }
  }
    
  hideLoadingScreen() {
    // Hide loading screen immediately, no artificial delay
    const loadingScreen = document.getElementById("loading-screen");
    const dashboard = document.getElementById("dashboard");

    if (loadingScreen && dashboard) {
      loadingScreen.style.opacity = "0";
      setTimeout(() => {
        loadingScreen.style.display = "none";
        dashboard.style.display = "flex";
      }, 500); // Fade out animation only
    }
  }

  toggleMobileMenu() {
    const sidebar = document.querySelector(".sidebar");
    if (sidebar) {
      sidebar.classList.toggle("mobile-open");
    }
  }

  closeMobileMenu() {
    const sidebar = document.querySelector(".sidebar");
    if (sidebar) {
      sidebar.classList.remove("mobile-open");
    }
  }

  setupKeyboardShortcuts() {
    document.addEventListener("keydown", (event) => {
      // Don't trigger shortcuts when typing in inputs
      if (event.target.tagName === "INPUT" || 
          event.target.tagName === "TEXTAREA" || 
          event.target.isContentEditable) {
        return;
      }

      // ESC - Close mobile menu
      if (event.key === "Escape") {
        this.closeMobileMenu();
      }

      // Ctrl+R or F5 - Refresh data (prevent default browser refresh)
      if ((event.ctrlKey && event.key === "r") || event.key === "F5") {
        event.preventDefault();
        this.refreshData();
      }

      // Arrow keys - Navigate between pages
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault();
        this.navigateWithKeys(event.key === "ArrowRight");
      }

      // Number keys 1-5 - Quick page navigation
      if (event.key >= "1" && event.key <= "5" && !event.ctrlKey && !event.altKey && !event.shiftKey) {
        const pages = ["overview", "sites", "system", "external-services", "tools"];
        const pageIndex = parseInt(event.key, 10) - 1;
        if (pageIndex < pages.length) {
          this.navigateToPage(pages[pageIndex]);
        }
      }
    });
  }

  navigateWithKeys(forward) {
    const pages = ["overview", "sites", "system", "external-services", "tools"];
    const currentIndex = pages.indexOf(this.state.getCurrentPage());
    
    if (currentIndex === -1) return;
    
    let nextIndex;
    if (forward) {
      nextIndex = (currentIndex + 1) % pages.length;
    } else {
      nextIndex = (currentIndex - 1 + pages.length) % pages.length;
    }
    
    this.navigateToPage(pages[nextIndex]);
  }
    
  startClock() {
    const updateClock = () => {
      const now = new Date();
      const timeString = now.toLocaleTimeString("en-US", {
        hour12: false,
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });

      const serverTime = document.getElementById("server-time");
      if (serverTime) {
        serverTime.textContent = timeString;
      }
    };

    updateClock();
    setInterval(updateClock, 1000);
  }
    
  loadInitialData() {
    this.loadOverviewData();
    this.updateLastRefresh();

    // Set up auto-refresh
    const timer = setInterval(() => {
      this.refreshData();
    }, this.state.refreshInterval);
    this.state.setRefreshTimer(timer);
  }
    
  refreshData() {
    // Clear service cache on manual refresh
    this.state.clearServiceCache();
    this.showRefreshAnimation();
    this.loadPageData(this.state.getCurrentPage());
    this.updateLastRefresh();
  }
    
  showRefreshAnimation() {
    const refreshBtn = document.getElementById("refresh-btn");
    const icon = refreshBtn.querySelector("i");

    icon.style.animation = "spin 1s linear";
    setTimeout(() => {
      icon.style.animation = "";
    }, 1000);
  }
    
  updateLastRefresh() {
    const updateTime = document.getElementById("update-time");
    if (updateTime) {
      updateTime.textContent = new Date().toLocaleTimeString();
    }
  }
    
  // Data Loading Methods
  async loadOverviewData() {
    try {
      // Show skeleton loaders while loading
      this.showSkeletonServiceStatus();

      // Load service status
      await this.loadServiceStatus();

      // Load uptime monitoring data
      this.loadUptimeData();

    } catch (error) {
      this.showError(
        `Failed to load dashboard data: ${error.message || error}`,
      );
    }
  }
    

    
  async loadServiceStatus() {
    try {
      // Fetch all services at once
      const response = await fetch("/api/services/status");
      
      if (!response.ok) {
        console.error('Service status API error:', response.status, response.statusText);
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const services = await response.json();
      console.log('Service status response:', services);

      // Update each service
      ["nginx", "php", "mysql", "redis"].forEach(service => {
        const status = services[service];
        const element = document.getElementById(`${service}-status`);

        if (element && status) {
          const statusIcon = element.querySelector(".service-status i");
          const versionSpan = element.querySelector(".service-version");

          if (statusIcon) {
            statusIcon.className = `fas fa-circle ${status.online ? "online" : "offline"}`;
          }
          if (versionSpan && status.version) {
            versionSpan.textContent = `v${status.version}`;
          }
        }
      });
    } catch (error) {
      console.error('Failed to load service status:', error);
      // Set all services to error state
      ["nginx", "php", "mysql", "redis"].forEach(service => {
        const element = document.getElementById(`${service}-status`);
        if (element) {
          const statusIcon = element.querySelector(".service-status i");
          const versionSpan = element.querySelector(".service-version");
          if (statusIcon) {
            statusIcon.className = "fas fa-circle offline";
          }
          if (versionSpan) {
            versionSpan.textContent = "Error";
          }
        }
      });
    }
  }
    
  async loadSites() {
    try {
      this.showSkeletonSites();
      const sites = await this.getApiData("/api/sites", []);
      const sitesGrid = document.getElementById("sites-grid");

      if (sitesGrid) {
        // Clear existing content
        sitesGrid.innerHTML = "";

        if (Array.isArray(sites) && sites.length > 0) {
          sites.forEach((site) => {
            if (this.isValidSite(site)) {
              const siteElement = this.createSiteElement(site);
              sitesGrid.appendChild(siteElement);
            }
          });
        } else {
          // Create no sites found element
          const noSitesElement = this.createNoSitesElement();
          sitesGrid.appendChild(noSitesElement);
        }
      }
    } catch (error) {
      console.error('Failed to load sites:', error);
      // Show error message to user
      const sitesGrid = document.getElementById("sites-grid");
      if (sitesGrid) {
        sitesGrid.innerHTML = "";
        const errorDiv = document.createElement("div");
        errorDiv.className = "site-card";
        
        const headerDiv = document.createElement("div");
        headerDiv.className = "site-header";
        
        const title = document.createElement("h3");
        title.textContent = "Error Loading Sites";
        
        headerDiv.appendChild(title);
        
        const infoDiv = document.createElement("div");
        infoDiv.className = "site-info";
        
        const message = document.createElement("p");
        message.textContent = "Unable to load WordPress sites data.";
        
        infoDiv.appendChild(message);
        
        errorDiv.appendChild(headerDiv);
        errorDiv.appendChild(infoDiv);
        sitesGrid.appendChild(errorDiv);
      }
    }
  }
    
  async loadSystemInfo() {
    try {
      this.showSkeletonSystemInfo();
      const sysInfo = await this.getApiData("/api/system/info", {});
      const systemInfo = document.getElementById("system-info");

      if (systemInfo && typeof sysInfo === "object") {
        // Clear existing content
        systemInfo.innerHTML = "";

        const infoItems = [
          {
            label: "OS",
            value: this.sanitizeInput(sysInfo.os) || "Ubuntu 24.04 LTS",
          },
          {
            label: "Kernel",
            value: this.sanitizeInput(sysInfo.kernel) || "Loading...",
          },
          {
            label: "Network",
            value: this.sanitizeInput(sysInfo.network) || "Loading..."
          }
        ];

        infoItems.forEach(item => {
          const infoElement = this.createInfoElement(item.label, item.value);
          systemInfo.appendChild(infoElement);
        });
      }

    } catch (error) {
      console.error('Failed to load system information:', error);
      this.showErrorSystemInfo();
    }
  }
    
  // API Methods - Delegated to module
  async getApiData(endpoint, fallback) {
    return this.api.getApiData(endpoint, fallback);
  }

  async postApiData(endpoint, data = {}) {
    return this.api.postApiData(endpoint, data);
  }

  async getServiceStatus(service) {
    return this.api.getServiceStatus(service);
  }
    
  showError(message) {
    this.utils.showError(message);
  }
    
  // Utility methods - Delegated to module
  sanitizeInput(input) {
    return this.utils.sanitizeInput(input);
  }

  sanitizeNumeric(input, fallback = "0") {
    return this.utils.sanitizeNumeric(input, fallback);
  }

  sanitizePercentage(input, fallback = "0%") {
    return this.utils.sanitizePercentage(input, fallback);
  }

  sanitizeUrl(input, fallback = "") {
    return this.utils.sanitizeUrl(input, fallback);
  }

  setTextContent(elementId, content) {
    this.utils.setTextContent(elementId, content);
  }

  normalizeMonitorCount(value) {
    const numericValue = Number(value);
    if (Number.isFinite(numericValue) && numericValue >= 0) {
      return Math.floor(numericValue);
    }
    return 0;
  }

  // Skeleton loader helpers



  showSkeletonServiceStatus() {
    const services = ["nginx", "php", "mysql", "redis"];
    services.forEach(service => {
      const element = document.getElementById(`${service}-status`);
      if (element) {
        const statusIcon = element.querySelector(".service-status i");
        const versionSpan = element.querySelector(".service-version");
        
        if (statusIcon) {
          statusIcon.className = "fas fa-circle";
        }
        if (versionSpan) {
          versionSpan.textContent = "v--";
        }
        // Remove any error styling
        element.style.opacity = "1";
      }
    });
  }

  showSkeletonSites() {
    const sitesGrid = document.getElementById("sites-grid");
    if (sitesGrid) {
      let html = '';
      for (let i = 0; i < 3; i++) {
        html += `
          <div class="skeleton-card">
            <div class="skeleton skeleton-title"></div>
            <div class="skeleton skeleton-text"></div>
            <div class="skeleton skeleton-text short"></div>
          </div>
        `;
      }
      sitesGrid.innerHTML = html;
    }
  }

  showSkeletonSystemInfo() {
    const systemInfo = document.getElementById("system-info");
    if (systemInfo) {
      let html = '';
      for (let i = 0; i < 3; i++) {
        html += `
          <div class="skeleton skeleton-text"></div>
        `;
      }
      systemInfo.innerHTML = html;
    }
  }

  // Empty state helpers
  createEmptyState(type, icon, title, message, actionText = null, actionCallback = null) {
    const emptyState = document.createElement('div');
    emptyState.className = `empty-state ${type}`;
    
    let html = `
      <i class="fas fa-${icon} empty-state-icon"></i>
      <h3 class="empty-state-title">${this.sanitizeInput(title)}</h3>
      <p class="empty-state-message">${this.sanitizeInput(message)}</p>
    `;
    
    if (actionText && actionCallback) {
      html += `
        <div class="empty-state-action">
          <button class="btn btn-primary" data-action="empty-state-action">${this.sanitizeInput(actionText)}</button>
        </div>
      `;
    }
    
    emptyState.innerHTML = html;
    
    if (actionText && actionCallback) {
      const btn = emptyState.querySelector('[data-action="empty-state-action"]');
      btn.addEventListener('click', actionCallback);
    }
    
    return emptyState;
  }

  showEmptyUptimeMonitors() {
    const uptimeContainer = document.getElementById("uptime-summary");
    if (uptimeContainer) {
      const emptyState = this.createEmptyState(
        'warning',
        'radar',
        'Uptime Monitoring Not Configured',
        'Set up Uptime Robot monitoring to track site availability'
      );
      uptimeContainer.innerHTML = '';
      uptimeContainer.appendChild(emptyState);
    }
  }

  showErrorSystemInfo() {
    const systemInfo = document.getElementById("system-info");
    if (systemInfo) {
      const emptyState = this.createEmptyState(
        'error',
        'exclamation-circle',
        'Unable to Load System Information',
        'There was an error retrieving system data',
        'Retry',
        () => this.loadSystemInfo()
      );
      systemInfo.innerHTML = '';
      systemInfo.appendChild(emptyState);
    }
  }
    
  isValidActivity(activity) {
    return this.utils.isValidActivity(activity);
  }

  isValidAlert(alert) {
    return this.utils.isValidAlert(alert);
  }

  isValidSite(site) {
    return this.utils.isValidSite(site);
  }
    
  createActivityElement(activity) {
    const iconClass = this.sanitizeInput(activity.icon) || "fa-info-circle";
    
    return this.utils.createContentElement({
      containerClass: "activity-item",
      iconClass: "activity-icon",
      contentClass: "activity-content",
      messageText: activity.message,
      timeText: activity.time,
      timeClass: "activity-time",
      iconType: iconClass,
    });
  }

  createAlertElement(alert) {
    const alertType = this.sanitizeInput(alert.type) || "info";

    return this.utils.createContentElement({
      containerClass: `alert-item ${alertType}`,
      iconClass: `alert-icon ${alertType}`,
      contentClass: "alert-content",
      messageText: alert.message,
      timeText: alert.time,
      timeClass: "alert-time",
      iconType: this.getAlertIcon(alertType),
    });
  }
    
  // Helper method to create site card structure - eliminates duplication
  createSiteCardStructure(titleText) {
    const siteDiv = document.createElement("div");
    siteDiv.className = "site-card";

    const headerDiv = document.createElement("div");
    headerDiv.className = "site-header";

    const title = document.createElement("h3");
    title.textContent = titleText;

    headerDiv.appendChild(title);
    siteDiv.appendChild(headerDiv);

    return { siteDiv, headerDiv };
  }
  
  createSiteElement(site) {
    const { siteDiv, headerDiv } = this.createSiteCardStructure(this.sanitizeInput(site.domain));

    const statusDiv = document.createElement("div");
    statusDiv.className = "site-status";

    const statusIndicator = document.createElement("span");
    const sanitizedStatus = this.sanitizeInput(site.status) || "unknown";
    statusIndicator.className = `status-indicator ${sanitizedStatus}`;

    const statusText = document.createTextNode(sanitizedStatus);

    statusDiv.appendChild(statusIndicator);
    statusDiv.appendChild(statusText);
    headerDiv.appendChild(statusDiv);

    // Site info
    const infoDiv = document.createElement("div");
    infoDiv.className = "site-info";

    const wpInfo = document.createElement("p");
    const wpLabel = document.createElement("strong");
    wpLabel.textContent = "WordPress: ";
    wpInfo.appendChild(wpLabel);
    wpInfo.appendChild(document.createTextNode(this.sanitizeInput(site.wp_version) || "Unknown"));

    const sslInfo = document.createElement("p");
    const sslLabel = document.createElement("strong");
    sslLabel.textContent = "SSL: ";
    sslInfo.appendChild(sslLabel);
    sslInfo.appendChild(document.createTextNode(this.sanitizeInput(site.ssl_status) || "Unknown"));

    infoDiv.appendChild(wpInfo);
    infoDiv.appendChild(sslInfo);
    siteDiv.appendChild(infoDiv);

    return siteDiv;
  }
    
  createNoSitesElement() {
    const { siteDiv } = this.createSiteCardStructure("No sites found");

    const infoDiv = document.createElement("div");
    infoDiv.className = "site-info";

    const message = document.createElement("p");
    message.textContent = "No WordPress sites are currently configured.";

    infoDiv.appendChild(message);
    siteDiv.appendChild(infoDiv);

    return siteDiv;
  }
  
  createInfoElement(label, value) {
    const infoDiv = document.createElement("div");
    infoDiv.className = "info-item";

    const labelElement = document.createElement("strong");
    labelElement.textContent = `${label}:`;

    const valueElement = document.createElement("span");
    valueElement.textContent = value;

    infoDiv.appendChild(labelElement);
    infoDiv.appendChild(valueElement);

    return infoDiv;
  }
    
  // Cleanup method
  destroy() {
    this.state.clearRefreshTimer();
    this.charts.destroy();
  }

  // Tools management methods
  async loadToolsData() {
    // Tools are now static links - no status checking needed
  }

  // External services monitoring with dynamic service configuration
  async loadExternalServices() {
    try {
      const container = document.getElementById("external-services-grid");
      const settingsContainer = document.getElementById("external-services-settings");
      if (!container || !settingsContainer) return;

      container.innerHTML = "";

      // Get service definitions first (always available)
      const serviceDefinitions = this.getServiceDefinitions();
      
      // Try to fetch from API, but fall back to definitions if it fails
      const response = await this.getApiData("/api/external-services/config", {});
      let services = response.services || response;
      
      // If API failed or returned empty, use all services from definitions
      if (!services || Object.keys(services).length === 0) {
        services = {};
        Object.keys(serviceDefinitions).forEach(key => {
          services[key] = true;
        });
      }
      
      // Load preferences from cookie (client-side only)
      let preferences = this.loadServicePreferences() || {};
      let serviceOrder = this.getServiceOrder();

      // Render settings panel in dedicated container
      this.renderServiceSettings(settingsContainer, services, serviceDefinitions, preferences);

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
        container.appendChild(emptyState);
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
        container.appendChild(categoryHeader);

        // Create category container
        const categoryContainer = document.createElement("div");
        categoryContainer.className = "service-category-grid";
        categoryContainer.dataset.category = category;

        // Fetch and display each service in the category
        for (const { key: serviceKey, def: serviceDef } of servicesByCategory[category]) {
          if (serviceDef.useFeed) {
            // Load from RSS/Atom feed via backend proxy
            await this.loadFeedService(categoryContainer, serviceKey, serviceDef);
          } else if (serviceDef.corsEnabled && serviceDef.api) {
            // Load from API directly
            await this.loadStatusPageService(categoryContainer, serviceKey, serviceDef);
          } else {
            // Display static link card
            this.displayStaticServiceCard(categoryContainer, serviceKey, serviceDef);
          }
        }

        container.appendChild(categoryContainer);
      }
      
      // Enable drag and drop for service cards
      this.enableServiceDragDrop(container);
    } catch (error) {
      console.error('Failed to load external services:', error);
      const container = document.getElementById("external-services-grid");
      if (container) {
        container.innerHTML = "";
        const errorDiv = document.createElement("div");
        errorDiv.className = "error-state";
        errorDiv.innerHTML = `
          <div class="error-icon">
            <i class="fas fa-exclamation-circle"></i>
          </div>
          <h3>Error Loading External Services</h3>
          <p>Failed to fetch external service status. Please try again later.</p>
        `;
        container.appendChild(errorDiv);
      }
    }
  }

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

  deleteCookie(name) {
    document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  }

  // Get service order from cookie
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
      'aws', 'cloudflare', 'cloudways', 'digitalocean', 'googlecloud', 'hostinger', 'kinsta', 'linode', 
      'oracle', 'ovh', 'scaleway', 'upcloud', 'vercel', 'vultr', 'wpvip',
      // Developer Tools
      'github', 'gitlab', 'notion', 'postmark', 'twilio',
      // Payment Processing
      'coinbase', 'paypal', 'recurly', 'square', 'stripe',
      // Communication
      'brevo', 'discord', 'mailgun', 'slack', 'zoom',
      // E-Commerce
      'intuit', 'shopify',
      // Media & Content
      'automattic', 'dropbox', 'reddit', 'udemy', 'vimeo', 'wistia',
      // Gaming
      'epicgames',
      // AI & Machine Learning
      'openai',
      // Advertising
      'googleads', 'googlesearch', 'googleworkspace', 'microsoftads',
      // Security
      'letsencrypt', 'cloudflareflare'
    ];
  }

  // Save service order to cookie
  saveServiceOrder(orderArray) {
    this.setCookie('serviceOrder', encodeURIComponent(JSON.stringify(orderArray)), 365);
  }

  // Get all service definitions
  getServiceDefinitions() {
    return {
      // HOSTING & INFRASTRUCTURE
      aws: {
        name: 'AWS',
        category: 'Hosting & Infrastructure',
        url: 'https://health.aws.amazon.com/health/status',
        icon: 'fa-server',
        color: 'aws-icon',
        corsEnabled: false,
        statusText: 'Visit status page'
      },
      cloudflare: {
        name: 'Cloudflare',
        category: 'Hosting & Infrastructure',
        api: 'https://www.cloudflarestatus.com/api/v2/status.json',
        url: 'https://www.cloudflarestatus.com/',
        icon: 'fa-cloud',
        color: 'cloudflare-icon',
        corsEnabled: true
      },
      cloudways: {
        name: 'Cloudways',
        category: 'Hosting & Infrastructure',
        api: 'https://status.cloudways.com/api/v2/status.json',
        url: 'https://status.cloudways.com/',
        icon: 'fa-cloud-upload-alt',
        color: 'cloudways-icon',
        corsEnabled: true
      },
      digitalocean: {
        name: 'DigitalOcean',
        category: 'Hosting & Infrastructure',
        api: 'https://status.digitalocean.com/api/v2/status.json',
        url: 'https://status.digitalocean.com/',
        icon: 'fa-water',
        color: 'digitalocean-icon',
        corsEnabled: true
      },
      googlecloud: {
        name: 'Google Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'googlecloud',
        url: 'https://status.cloud.google.com/',
        icon: 'fa-google',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      hostinger: {
        name: 'Hostinger',
        category: 'Hosting & Infrastructure',
        api: 'https://statuspage.hostinger.com/api/v2/status.json',
        url: 'https://statuspage.hostinger.com/',
        icon: 'fa-h-square',
        color: 'hostinger-icon',
        corsEnabled: true
      },
      kinsta: {
        name: 'Kinsta',
        category: 'Hosting & Infrastructure',
        api: 'https://status.kinsta.com/api/v2/status.json',
        url: 'https://status.kinsta.com/',
        icon: 'fa-bolt',
        color: 'kinsta-icon',
        corsEnabled: true
      },
      linode: {
        name: 'Linode',
        category: 'Hosting & Infrastructure',
        api: 'https://status.linode.com/api/v2/status.json',
        url: 'https://status.linode.com/',
        icon: 'fa-cube',
        color: 'linode-icon',
        corsEnabled: true
      },
      oracle: {
        name: 'Oracle Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'oracle',
        url: 'https://ocistatus.oraclecloud.com/',
        icon: 'fa-database',
        color: 'oracle-icon',
        corsEnabled: false,
        useFeed: true
      },
      ovh: {
        name: 'OVH Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'ovh',
        url: 'https://public-cloud.status-ovhcloud.com/',
        icon: 'fa-cloud',
        color: 'ovh-icon',
        corsEnabled: false,
        useFeed: true
      },
      scaleway: {
        name: 'Scaleway',
        category: 'Hosting & Infrastructure',
        api: 'https://status.scaleway.com/api/v2/status.json',
        url: 'https://status.scaleway.com/',
        icon: 'fa-layer-group',
        color: 'scaleway-icon',
        corsEnabled: true
      },
      upcloud: {
        name: 'UpCloud',
        category: 'Hosting & Infrastructure',
        api: 'https://status.upcloud.com/api/v2/status.json',
        url: 'https://status.upcloud.com/',
        icon: 'fa-arrow-up',
        color: 'upcloud-icon',
        corsEnabled: true
      },
      vercel: {
        name: 'Vercel',
        category: 'Hosting & Infrastructure',
        api: 'https://www.vercel-status.com/api/v2/status.json',
        url: 'https://www.vercel-status.com/',
        icon: 'fa-triangle',
        color: 'vercel-icon',
        corsEnabled: true
      },
      vultr: {
        name: 'Vultr',
        category: 'Hosting & Infrastructure',
        feedType: 'vultr',
        url: 'https://status.vultr.com/',
        icon: 'fa-bolt',
        color: 'vultr-icon',
        corsEnabled: false,
        useFeed: true
      },
      wpvip: {
        name: 'WordPress VIP',
        category: 'Hosting & Infrastructure',
        feedType: 'wpvip',
        url: 'https://wpvipstatus.com/',
        icon: 'fa-wordpress',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      
      // DEVELOPER TOOLS
      github: {
        name: 'GitHub',
        category: 'Developer Tools',
        api: 'https://www.githubstatus.com/api/v2/status.json',
        url: 'https://www.githubstatus.com/',
        icon: 'fa-github',
        color: 'github-icon',
        corsEnabled: true
      },
      gitlab: {
        name: 'GitLab',
        category: 'Developer Tools',
        feedType: 'gitlab',
        url: 'https://status.gitlab.com/',
        icon: 'fa-gitlab',
        color: 'gitlab-icon',
        corsEnabled: false,
        useFeed: true
      },
      notion: {
        name: 'Notion',
        category: 'Developer Tools',
        api: 'https://www.notion-status.com/api/v2/status.json',
        url: 'https://www.notion-status.com/',
        icon: 'fa-file-alt',
        color: 'notion-icon',
        corsEnabled: true
      },
      postmark: {
        name: 'Postmark',
        category: 'Developer Tools',
        feedType: 'postmark',
        url: 'https://status.postmarkapp.com/',
        icon: 'fa-paper-plane',
        color: 'postmark-icon',
        corsEnabled: false,
        useFeed: true
      },
      twilio: {
        name: 'Twilio',
        category: 'Developer Tools',
        api: 'https://status.twilio.com/api/v2/status.json',
        url: 'https://status.twilio.com/',
        icon: 'fa-sms',
        color: 'twilio-icon',
        corsEnabled: true
      },
      
      // PAYMENT PROCESSING
      coinbase: {
        name: 'Coinbase',
        category: 'Payment Processing',
        api: 'https://status.coinbase.com/api/v2/status.json',
        url: 'https://status.coinbase.com/',
        icon: 'fa-bitcoin',
        color: 'coinbase-icon',
        corsEnabled: true
      },
      paypal: {
        name: 'PayPal',
        category: 'Payment Processing',
        feedType: 'paypal',
        url: 'https://www.paypal-status.com/product/production',
        icon: 'fa-paypal',
        color: 'paypal-icon',
        corsEnabled: false,
        useFeed: true
      },
      recurly: {
        name: 'Recurly',
        category: 'Payment Processing',
        feedType: 'recurly',
        url: 'https://status.recurly.com/',
        icon: 'fa-repeat',
        color: 'recurly-icon',
        corsEnabled: false,
        useFeed: true
      },
      square: {
        name: 'Square',
        category: 'Payment Processing',
        feedType: 'square',
        url: 'https://www.issquareup.com/',
        icon: 'fa-square',
        color: 'square-icon',
        corsEnabled: false,
        useFeed: true
      },
      stripe: {
        name: 'Stripe',
        category: 'Payment Processing',
        feedType: 'stripe',
        url: 'https://status.stripe.com/',
        icon: 'fa-credit-card',
        color: 'stripe-icon',
        corsEnabled: false,
        useFeed: true
      },
      
      // COMMUNICATION
      discord: {
        name: 'Discord',
        category: 'Communication',
        api: 'https://discordstatus.com/api/v2/status.json',
        url: 'https://discordstatus.com/',
        icon: 'fa-discord',
        color: 'discord-icon',
        corsEnabled: true
      },
      brevo: {
        name: 'Brevo',
        category: 'Communication',
        feedType: 'brevo',
        url: 'https://status.brevo.com/',
        icon: 'fa-envelope-open',
        color: 'brevo-icon',
        corsEnabled: false,
        useFeed: true
      },
      mailgun: {
        name: 'Mailgun',
        category: 'Communication',
        api: 'https://status.mailgun.com/api/v2/status.json',
        url: 'https://status.mailgun.com/',
        icon: 'fa-envelope',
        color: 'mailgun-icon',
        corsEnabled: true
      },
      slack: {
        name: 'Slack',
        category: 'Communication',
        feedType: 'slack',
        url: 'https://slack-status.com/',
        icon: 'fa-slack',
        color: 'slack-icon',
        corsEnabled: false,
        useFeed: true
      },
      zoom: {
        name: 'Zoom',
        category: 'Communication',
        api: 'https://www.zoomstatus.com/api/v2/status.json',
        url: 'https://www.zoomstatus.com/',
        icon: 'fa-video',
        color: 'zoom-icon',
        corsEnabled: true
      },
      
      // E-COMMERCE
      intuit: {
        name: 'Intuit',
        category: 'E-Commerce',
        api: 'https://status.developer.intuit.com/api/v2/status.json',
        url: 'https://status.developer.intuit.com/',
        icon: 'fa-calculator',
        color: 'intuit-icon',
        corsEnabled: true
      },
      shopify: {
        name: 'Shopify',
        category: 'E-Commerce',
        api: 'https://www.shopifystatus.com/api/v2/status.json',
        url: 'https://www.shopifystatus.com/',
        icon: 'fa-shopping-bag',
        color: 'shopify-icon',
        corsEnabled: true
      },
      
      // MEDIA & CONTENT
      automattic: {
        name: 'Automattic',
        category: 'Media & Content',
        feedType: 'automattic',
        url: 'https://automatticstatus.com/',
        icon: 'fa-wordpress-simple',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      dropbox: {
        name: 'Dropbox',
        category: 'Media & Content',
        api: 'https://status.dropbox.com/api/v2/status.json',
        url: 'https://status.dropbox.com/',
        icon: 'fa-dropbox',
        color: 'dropbox-icon',
        corsEnabled: true
      },
      reddit: {
        name: 'Reddit',
        category: 'Media & Content',
        api: 'https://www.redditstatus.com/api/v2/status.json',
        url: 'https://www.redditstatus.com/',
        icon: 'fa-reddit',
        color: 'reddit-icon',
        corsEnabled: true
      },
      udemy: {
        name: 'Udemy',
        category: 'Media & Content',
        api: 'https://status.udemy.com/api/v2/status.json',
        url: 'https://status.udemy.com/',
        icon: 'fa-graduation-cap',
        color: 'udemy-icon',
        corsEnabled: true
      },
      vimeo: {
        name: 'Vimeo',
        category: 'Media & Content',
        api: 'https://www.vimeostatus.com/api/v2/status.json',
        url: 'https://status.vimeo.com/',
        icon: 'fa-vimeo',
        color: 'vimeo-icon',
        corsEnabled: true
      },
      wistia: {
        name: 'Wistia',
        category: 'Media & Content',
        feedType: 'wistia',
        url: 'https://status.wistia.com/',
        icon: 'fa-play-circle',
        color: 'wistia-icon',
        corsEnabled: false,
        useFeed: true
      },
      
      // GAMING
      epicgames: {
        name: 'Epic Games',
        category: 'Gaming',
        api: 'https://status.epicgames.com/api/v2/status.json',
        url: 'https://status.epicgames.com/',
        icon: 'fa-gamepad',
        color: 'epic-icon',
        corsEnabled: true
      },
      
      // AI & MACHINE LEARNING
      openai: {
        name: 'OpenAI',
        category: 'AI & Machine Learning',
        url: 'https://status.openai.com/',
        icon: 'fa-brain',
        color: 'openai-icon',
        corsEnabled: false,
        statusText: 'Visit status page'
      },
      
      // ADVERTISING
      googleads: {
        name: 'Google Ads',
        category: 'Advertising',
        feedType: 'googleads',
        url: 'https://ads.google.com/status/publisher/',
        icon: 'fa-ad',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      googlesearch: {
        name: 'Google Search Console',
        category: 'Advertising',
        feedType: 'googlesearch',
        url: 'https://status.search.google.com/',
        icon: 'fa-search',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      googleworkspace: {
        name: 'Google Workspace',
        category: 'Advertising',
        feedType: 'googleworkspace',
        url: 'https://www.google.com/appsstatus/dashboard/',
        icon: 'fa-google',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      microsoftads: {
        name: 'Microsoft Advertising',
        category: 'Advertising',
        feedType: 'microsoftads',
        url: 'https://status.ads.microsoft.com/',
        icon: 'fa-microsoft',
        color: 'microsoft-icon',
        corsEnabled: false,
        useFeed: true
      },
      
      // SECURITY
      letsencrypt: {
        name: "Let's Encrypt",
        category: 'Security',
        feedType: 'letsencrypt',
        url: 'https://letsencrypt.status.io/',
        icon: 'fa-lock',
        color: 'letsencrypt-icon',
        corsEnabled: false,
        useFeed: true
      },
      cloudflareflare: {
        name: 'Cloudflare Flare',
        category: 'Security',
        feedType: 'cloudflare-flare',
        url: 'https://status.flare.io/',
        icon: 'fa-shield-alt',
        color: 'cloudflare-icon',
        corsEnabled: false,
        useFeed: true
      }
    };
  }

  // Render the settings panel
  renderServiceSettings(settingsContainer, services, serviceDefinitions, preferences) {
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
    for (const [serviceKey, isAvailable] of Object.entries(services)) {
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
      'Payment Processing',
      'Communication',
      'E-Commerce',
      'Media & Content',
      'Gaming',
      'AI & Machine Learning',
      'Advertising',
      'Security',
      'Other'
    ];

    categoryOrder.forEach(categoryName => {
      if (categories[categoryName]) {
        const categorySection = document.createElement("div");
        categorySection.className = "settings-category";
        
        const categoryTitle = document.createElement("h4");
        categoryTitle.className = "category-title";
        categoryTitle.textContent = categoryName;
        categorySection.appendChild(categoryTitle);
        
        const categoryGrid = document.createElement("div");
        categoryGrid.className = "settings-grid";
        
        // Sort services alphabetically within category
        categories[categoryName].sort((a, b) => {
          return serviceDefinitions[a].name.localeCompare(serviceDefinitions[b].name);
        });
        
        categories[categoryName].forEach(serviceKey => {
          const isEnabled = preferences[serviceKey] === true;
          
          const toggleLabel = document.createElement("label");
          toggleLabel.className = "service-toggle";
          const checkbox = document.createElement("input");
          checkbox.type = "checkbox";
          checkbox.checked = isEnabled;
          checkbox.dataset.service = serviceKey;
          checkbox.addEventListener("change", () => {
            pendingChanges[serviceKey] = checkbox.checked;
            saveButton.disabled = false;
            saveButton.classList.add('has-changes');
          });
          
          const serviceName = document.createElement("span");
          serviceName.textContent = serviceDefinitions[serviceKey].name;
          
          toggleLabel.appendChild(checkbox);
          toggleLabel.appendChild(serviceName);
          categoryGrid.appendChild(toggleLabel);
        });
        
        categorySection.appendChild(categoryGrid);
        settingsContent.appendChild(categorySection);
      }
    });
    
    // Add save button
    const saveButton = document.createElement("button");
    saveButton.className = "settings-save-btn";
    saveButton.disabled = true;
    saveButton.innerHTML = `<i class="fas fa-save"></i> Save Changes`;
    saveButton.addEventListener("click", async () => {
      if (Object.keys(pendingChanges).length > 0) {
        await this.saveServicePreferences(pendingChanges);
        pendingChanges.length = 0;
        Object.keys(pendingChanges).forEach(key => delete pendingChanges[key]);
        saveButton.disabled = true;
        saveButton.classList.remove('has-changes');
        
        // Collapse the settings panel
        settingsContent.classList.add('collapsed');
        const toggleIcon = settingsToggle.querySelector('.toggle-icon');
        if (toggleIcon) {
          toggleIcon.className = 'fas fa-chevron-down toggle-icon';
        }
      }
    });
    
    settingsContent.appendChild(saveButton);
  }

  // Enable drag and drop for service cards
  enableServiceDragDrop(container) {
    const cards = container.querySelectorAll('.external-service-card');
    let draggedElement = null;
    
    cards.forEach(card => {
      card.draggable = true;
      
      card.addEventListener('dragstart', (e) => {
        draggedElement = card;
        card.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/html', card.innerHTML);
      });
      
      card.addEventListener('dragend', () => {
        card.classList.remove('dragging');
        
        // Remove drag-over class from all cards
        cards.forEach(c => c.classList.remove('drag-over'));
        
        // Save new order
        const newOrder = Array.from(container.children)
          .filter(child => child.classList.contains('external-service-card'))
          .map(child => child.dataset.serviceKey);
        
        this.saveServiceOrder(newOrder);
      });
      
      card.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        
        const afterElement = this.getDragAfterElement(container, e.clientY);
        if (afterElement == null) {
          container.appendChild(draggedElement);
        } else {
          container.insertBefore(draggedElement, afterElement);
        }
      });
      
      card.addEventListener('dragenter', (e) => {
        if (e.target.classList.contains('external-service-card') && e.target !== draggedElement) {
          e.target.classList.add('drag-over');
        }
      });
      
      card.addEventListener('dragleave', (e) => {
        if (e.target.classList.contains('external-service-card')) {
          e.target.classList.remove('drag-over');
        }
      });
    });
  }

  // Get the element that should be placed after the dragged element
  getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('.external-service-card:not(.dragging)')];
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;
      
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  }

  async saveServicePreferences(changes) {
    try {
      // Get all service definitions to validate
      const serviceDefinitions = this.getServiceDefinitions();
      
      // Get current preferences from cookie
      let preferences = {};
      const cookiePrefs = this.getCookie('servicePreferences');
      if (cookiePrefs) {
        try {
          preferences = JSON.parse(decodeURIComponent(cookiePrefs));
        } catch (e) {
          console.error('Failed to parse cookie preferences:', e);
          preferences = {};
        }
      }
      
      // Update all pending preferences
      Object.keys(changes).forEach(serviceKey => {
        if (serviceDefinitions[serviceKey]) {
          preferences[serviceKey] = Boolean(changes[serviceKey]);
        }
      });
      
      // Save to cookie (1 year expiration)
      this.setCookie('servicePreferences', encodeURIComponent(JSON.stringify(preferences)), 365);
      
      // Re-render services without reloading settings panel
      const container = document.getElementById("external-services-grid");
      if (container) {
        // Clear only the service cards
        container.innerHTML = "";
        
        // Get service data
        const services = await this.getExternalServicesAvailability();
        const serviceOrder = this.getServiceOrder();
        
        // Get service keys in custom order
        let orderedServiceKeys = serviceOrder.filter(key => services[key]);
        Object.keys(services).forEach(key => {
          if (!orderedServiceKeys.includes(key)) {
            orderedServiceKeys.push(key);
          }
        });
        
        // Re-render enabled services (must be explicitly enabled)
        for (const serviceKey of orderedServiceKeys) {
          if (serviceDefinitions[serviceKey]) {
            const isServiceEnabled = preferences[serviceKey] === true;
            
            if (isServiceEnabled) {
              const serviceDef = serviceDefinitions[serviceKey];
              if (serviceDef.useFeed) {
                await this.loadFeedService(container, serviceKey, serviceDef);
              } else if (serviceDef.corsEnabled && serviceDef.api) {
                await this.loadStatusPageService(container, serviceKey, serviceDef);
              } else {
                this.displayStaticServiceCard(container, serviceKey, serviceDef);
              }
            }
          }
        }
        
        // Re-enable drag and drop
        this.enableServiceDragDrop(container);
      }
      
      this.showNotification("Preferences saved successfully", "success");
    } catch (error) {
      console.error('Failed to save service preferences:', error);
      this.showNotification("Failed to save preferences", "error");
    }
  }

  // Display static service card for services without CORS support
  displayStaticServiceCard(container, serviceKey, serviceDef) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = "external-service-card static";
    serviceLink.dataset.serviceKey = serviceKey;
    
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

  // Generic Statuspage.io service loader
  async loadStatusPageService(container, serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.state.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);
        
        const response = await fetch(serviceDef.api, {
          signal: controller.signal
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.state.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status || !data.status.indicator) {
        throw new Error('Invalid API response format');
      }

      const serviceLink = document.createElement("a");
      serviceLink.href = serviceDef.url;
      serviceLink.target = "_blank";
      serviceLink.rel = "noopener noreferrer";
      serviceLink.className = "external-service-card";
      serviceLink.dataset.serviceKey = serviceKey;
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";

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
      statusSpan.className = `service-status status-${statusColor}`;
      statusSpan.innerHTML = `<i class="fas fa-${statusIcon}"></i> `;
      statusSpan.appendChild(document.createTextNode(this.sanitizeInput(data.status.description)));
      
      infoDiv.appendChild(h3);
      infoDiv.appendChild(statusSpan);
      headerDiv.appendChild(iconDiv);
      headerDiv.appendChild(infoDiv);
      serviceLink.appendChild(headerDiv);
      
      container.appendChild(serviceLink);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} status:`, error);
      
      let errorMessage = 'Unable to fetch status';
      if (error.name === 'AbortError') {
        errorMessage = 'Request timed out';
      } else if (error.message && error.message.startsWith('HTTP error!')) {
        errorMessage = 'Service unavailable';
      }
      
      const errorLink = document.createElement("a");
      errorLink.href = serviceDef.url;
      errorLink.target = "_blank";
      errorLink.rel = "noopener noreferrer";
      errorLink.className = "external-service-card error";
      errorLink.dataset.serviceKey = serviceKey;
      
      const errorHeaderDiv = document.createElement("div");
      errorHeaderDiv.className = "service-header";
      
      const errorIconDiv = document.createElement("div");
      errorIconDiv.className = `service-icon ${serviceDef.color}`;
      errorIconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
      
      const errorInfoDiv = document.createElement("div");
      errorInfoDiv.className = "service-info";
      
      const errorH3 = document.createElement("h3");
      errorH3.textContent = serviceDef.name;
      
      const errorStatusSpan = document.createElement("span");
      errorStatusSpan.className = "service-status status-error";
      errorStatusSpan.innerHTML = `<i class="fas fa-times-circle"></i> `;
      errorStatusSpan.appendChild(document.createTextNode(errorMessage));
      
      errorInfoDiv.appendChild(errorH3);
      errorInfoDiv.appendChild(errorStatusSpan);
      errorHeaderDiv.appendChild(errorIconDiv);
      errorHeaderDiv.appendChild(errorInfoDiv);
      errorLink.appendChild(errorHeaderDiv);
      
      container.appendChild(errorLink);
    }
  }

  // Load service status from RSS/Atom feed via backend proxy
  async loadFeedService(container, serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.state.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);
        
        const response = await fetch(`/api/external-services/feed?feed=${encodeURIComponent(serviceDef.feedType)}`, {
          signal: controller.signal,
          credentials: 'include'
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.state.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status) {
        throw new Error('Invalid feed response format');
      }

      const serviceLink = document.createElement("a");
      serviceLink.href = serviceDef.url;
      serviceLink.target = "_blank";
      serviceLink.rel = "noopener noreferrer";
      serviceLink.className = "external-service-card";
      serviceLink.dataset.serviceKey = serviceKey;
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";

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
      statusSpan.className = `service-status status-${statusColor}`;
      statusSpan.innerHTML = `<i class="fas fa-${statusIcon}"></i> `;
      statusSpan.appendChild(document.createTextNode(this.sanitizeInput(data.status.description)));
      
      infoDiv.appendChild(h3);
      infoDiv.appendChild(statusSpan);
      headerDiv.appendChild(iconDiv);
      headerDiv.appendChild(infoDiv);
      serviceLink.appendChild(headerDiv);
      
      container.appendChild(serviceLink);
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} feed status:`, error);
      
      let errorMessage = 'Unable to fetch status';
      if (error.name === 'AbortError') {
        errorMessage = 'Request timed out';
      } else if (error.message && error.message.startsWith('HTTP error!')) {
        errorMessage = 'Service unavailable';
      }
      
      const errorLink = document.createElement("a");
      errorLink.href = serviceDef.url;
      errorLink.target = "_blank";
      errorLink.rel = "noopener noreferrer";
      errorLink.className = "external-service-card error";
      errorLink.dataset.serviceKey = serviceKey;
      
      const errorHeaderDiv = document.createElement("div");
      errorHeaderDiv.className = "service-header";
      
      const errorIconDiv = document.createElement("div");
      errorIconDiv.className = `service-icon ${serviceDef.color}`;
      errorIconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
      
      const errorInfoDiv = document.createElement("div");
      errorInfoDiv.className = "service-info";
      
      const errorH3 = document.createElement("h3");
      errorH3.textContent = serviceDef.name;
      
      const errorStatusSpan = document.createElement("span");
      errorStatusSpan.className = "service-status status-error";
      errorStatusSpan.innerHTML = `<i class="fas fa-times-circle"></i> `;
      errorStatusSpan.appendChild(document.createTextNode(errorMessage));
      
      errorInfoDiv.appendChild(errorH3);
      errorInfoDiv.appendChild(errorStatusSpan);
      errorHeaderDiv.appendChild(errorIconDiv);
      errorHeaderDiv.appendChild(errorInfoDiv);
      errorLink.appendChild(errorHeaderDiv);
      
      container.appendChild(errorLink);
    }
  }

  // Uptime monitoring methods
  async loadUptimeData() {
    try {
      await this.loadUptimeSummary();
      await this.loadUptimeMonitors();
    } catch (error) {
      console.error('Failed to load uptime monitoring data:', error);
      // Show fallback uptime error state
      this.showUptimeError();
    }
  }

  async loadUptimeSummary() {
    try {
      const summary = await this.getApiData("/api/monitoring/uptime", {});
      
      if (summary.configured) {
        const totalCount = this.normalizeMonitorCount(summary.total_monitors);
        const upCount = this.normalizeMonitorCount(summary.up_monitors);
        const downCount = this.normalizeMonitorCount(summary.down_monitors);

        this.setTextContent("total-monitors", totalCount);
        this.setTextContent("up-monitors", upCount);
        this.setTextContent("down-monitors", downCount);
      } else {
        this.showUptimeNotConfigured();
      }
    } catch (error) {
      console.error('Failed to load uptime summary:', error);
      this.showUptimeError();
    }
  }

  async loadUptimeMonitors() {
    try {
      const response = await this.getApiData("/api/monitoring/uptime/monitors", {});
      const monitorsContainer = document.getElementById("uptime-monitors");
      
      if (!monitorsContainer) return;
      
      if (!response.configured) {
        this.showUptimeNotConfigured();
        return;
      }
      
      const monitors = response.monitors || [];
      
      if (monitors.length === 0) {
        monitorsContainer.innerHTML = "";
        const emptyState = this.createEmptyState(
          'warning',
          'clock',
          'No Monitors Configured',
          'Add websites to monitor in your Uptime Robot dashboard'
        );
        monitorsContainer.appendChild(emptyState);
        return;
      }
      
      // Clear existing content
      monitorsContainer.innerHTML = '';
      
      monitors.forEach(monitor => {
        const monitorElement = this.createUptimeMonitorElement(monitor);
        monitorsContainer.appendChild(monitorElement);
      });
      
    } catch (error) {
      console.error('Failed to load uptime monitors:', error);
      this.showUptimeError();
    }
  }

  createUptimeMonitorElement(monitor) {
    const monitorDiv = document.createElement("div");
    monitorDiv.className = "uptime-monitor";
    
    const statusClass = this.getUptimeStatusClass(monitor.status_code);
    
    // Create elements programmatically to avoid XSS vulnerabilities
    const statusDiv = document.createElement("div");
    statusDiv.className = `monitor-status ${statusClass}`;
    
    const statusDot = document.createElement("span");
    statusDot.className = "status-dot";
    statusDiv.appendChild(statusDot);
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "monitor-info";
    
    const nameH4 = document.createElement("h4");
    nameH4.textContent = this.sanitizeInput(monitor.name);
    
    const urlP = document.createElement("p");
    urlP.className = "monitor-url";
    urlP.textContent = this.sanitizeUrl(monitor.url);
    
    infoDiv.appendChild(nameH4);
    infoDiv.appendChild(urlP);
    
    // Only show stats if they have meaningful values
    const hasStats = monitor.uptime_ratio > 0 || monitor.response_time > 0;
    
    if (hasStats) {
      const statsDiv = document.createElement("div");
      statsDiv.className = "monitor-stats";
      
      if (monitor.uptime_ratio > 0) {
        const uptimeStatDiv = document.createElement("div");
        uptimeStatDiv.className = "stat";
        
        const uptimeValue = document.createElement("span");
        uptimeValue.className = "stat-value";
        uptimeValue.textContent = this.sanitizeNumeric(monitor.uptime_ratio, "0") + "%";
        
        const uptimeLabel = document.createElement("span");
        uptimeLabel.className = "stat-label";
        uptimeLabel.textContent = "Uptime";
        
        uptimeStatDiv.appendChild(uptimeValue);
        uptimeStatDiv.appendChild(uptimeLabel);
        statsDiv.appendChild(uptimeStatDiv);
      }
      
      if (monitor.response_time > 0) {
        const responseStatDiv = document.createElement("div");
        responseStatDiv.className = "stat";
        
        const responseValue = document.createElement("span");
        responseValue.className = "stat-value";
        responseValue.textContent = this.sanitizeNumeric(monitor.response_time, "0") + "ms";
        
        const responseLabel = document.createElement("span");
        responseLabel.className = "stat-label";
        responseLabel.textContent = "Response";
        
        responseStatDiv.appendChild(responseValue);
        responseStatDiv.appendChild(responseLabel);
        statsDiv.appendChild(responseStatDiv);
      }
      
      monitorDiv.appendChild(statsDiv);
    }
    
    const statusTextDiv = document.createElement("div");
    statusTextDiv.className = "monitor-status-text";
    
    const statusText = document.createElement("span");
    statusText.className = "status-text";
    statusText.textContent = this.sanitizeInput(monitor.status);
    
    statusTextDiv.appendChild(statusText);
    
    monitorDiv.appendChild(statusDiv);
    monitorDiv.appendChild(infoDiv);
    monitorDiv.appendChild(statusTextDiv);
    
    return monitorDiv;
  }

  getUptimeStatusClass(statusCode) {
    switch (statusCode) {
      case 2: return 'up';
      case 8:
      case 9: return 'down';
      case 0: return 'paused';
      default: return 'unknown';
    }
  }

  showUptimeNotConfigured() {
    const monitorsContainer = document.getElementById("uptime-monitors");
    if (monitorsContainer) {
      // Clear existing content
      monitorsContainer.innerHTML = '';
      
      // Create status div
      const statusDiv = document.createElement("div");
      statusDiv.className = "uptime-status";
      
      // Create title
      const titleP = document.createElement("p");
      const titleStrong = document.createElement("strong");
      titleStrong.textContent = "Uptime Robot not configured";
      titleP.appendChild(titleStrong);
      
      // Create instructions
      const instrP = document.createElement("p");
      instrP.textContent = "To enable website monitoring:";
      
      // Create ordered list
      const ol = document.createElement("ol");
      
      // Create list items
      const li1 = document.createElement("li");
      li1.textContent = "Create a free account at ";
      const link = document.createElement("a");
      link.href = "https://uptimerobot.com/";
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = "UptimeRobot.com";
      li1.appendChild(link);
      
      const li2 = document.createElement("li");
      li2.textContent = "Get your API key from Settings > API Settings";
      
      const li3 = document.createElement("li");
      li3.textContent = "Configure it using: ";
      const code1 = document.createElement("code");
      code1.textContent = "sudo nano /etc/enginescript/uptimerobot.conf";
      li3.appendChild(code1);
      
      const li4 = document.createElement("li");
      li4.textContent = "Add: ";
      const code2 = document.createElement("code");
      code2.textContent = "api_key=your_api_key_here";
      li4.appendChild(code2);
      
      ol.appendChild(li1);
      ol.appendChild(li2);
      ol.appendChild(li3);
      ol.appendChild(li4);
      
      statusDiv.appendChild(titleP);
      statusDiv.appendChild(instrP);
      statusDiv.appendChild(ol);
      
      monitorsContainer.appendChild(statusDiv);
    }
    
    // Reset summary stats
    this.setTextContent("total-monitors", "--");
    this.setTextContent("up-monitors", "--");
    this.setTextContent("down-monitors", 0);
  }

  showUptimeError() {
    const monitorsContainer = document.getElementById("uptime-monitors");
    if (monitorsContainer) {
      monitorsContainer.innerHTML = "";
      const statusDiv = document.createElement("div");
      statusDiv.className = "uptime-status";
      
      const message = document.createElement("p");
      message.textContent = "Error loading uptime monitoring data. Please check your configuration and try again.";
      
      statusDiv.appendChild(message);
      monitorsContainer.appendChild(statusDiv);
    }
    this.setTextContent("down-monitors", 0);
  }

}

// Initialize dashboard when DOM is loaded
document.addEventListener("DOMContentLoaded", () => {
  // Only initialize if not already initialized
  if (!window.engineScriptDashboard) {
    window.engineScriptDashboard = new EngineScriptDashboard();
  }
});

// Handle page unload
window.addEventListener("beforeunload", () => {
  if (window.engineScriptDashboard) {
    window.engineScriptDashboard.destroy();
  }
});

// Security: Prevent frame embedding
if (window.top !== window.self) {
    window.top.location = window.self.location;
}
