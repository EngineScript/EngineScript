// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention

import { DashboardAPI } from './modules/api.js?v=2025.12.01.1';
import { DashboardState } from './modules/state.js?v=2025.12.01.1';
import { DashboardUtils } from './modules/utils.js?v=2025.12.01.1';
// External services loaded dynamically when needed (lazy loading)

class EngineScriptDashboard {
  constructor() {
    // Initialize modules
    this.api = new DashboardAPI();
    this.state = new DashboardState();
    this.utils = new DashboardUtils();
    this.externalServices = null; // Lazy loaded when needed

    // Legacy property references for compatibility
    this.currentPage = this.state.currentPage;
    this.refreshInterval = this.state.refreshInterval;
    this.allowedTimeRanges = this.state.allowedTimeRanges;
    this.allowedPages = this.state.allowedPages;
    this.allowedTools = this.state.allowedTools;

    this.init();
  }

  init() {
    this.initTheme(); // Initialize theme before rendering
    this.setupEventListeners();
    this.setupNavigation();
    this.startClock();
    this.api.loadCsrfToken(); // Load CSRF token before other API calls
    this.loadInitialData();
    this.hideLoadingScreen();
  }

  /**
   * Initialize theme from localStorage or system preference
   */
  initTheme() {
    const savedTheme = localStorage.getItem('dashboard-theme');
    if (savedTheme) {
      document.documentElement.setAttribute('data-theme', savedTheme);
    } else {
      // Check system preference
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
    }
  }

  /**
   * Toggle between dark and light themes
   */
  toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'dark';
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('dashboard-theme', newTheme);
  }

  setupEventListeners() {
    // Theme toggle button
    const themeToggle = document.getElementById("theme-toggle");
    if (themeToggle) {
      themeToggle.addEventListener("click", () => this.toggleTheme());
    }

    // Mobile menu toggle
    const mobileMenuToggle = document.getElementById("mobile-menu-toggle");
    if (mobileMenuToggle) {
      mobileMenuToggle.addEventListener("click", () => this.toggleMobileMenu());
    }

    // Close mobile menu when clicking outside
    document.addEventListener("click", (e) => {
      const sidebar = document.querySelector(".sidebar");
      const mobileToggle = document.getElementById("mobile-menu-toggle");
      // Guard: If toggle element not present, nothing to do
      if (!mobileToggle) return;
      
      if (sidebar && sidebar.classList.contains("mobile-open") && 
          !sidebar.contains(e.target) && 
          !mobileToggle.contains(e.target)) {
        this.closeMobileMenu();
      }
    });

    // Navigation using event delegation (single listener on parent)
    const sidebarNav = document.querySelector(".sidebar-nav");
    if (sidebarNav) {
      sidebarNav.addEventListener("click", (e) => {
        // Find the nav-item element (could be clicked on link or icon inside)
        const navItem = e.target.closest(".nav-item");
        if (!navItem) return;
        
        e.preventDefault();
        const page = this.sanitizeInput(navItem.dataset.page);
        if (this.state.isValidPage(page)) {
          this.navigateToPage(page);
          // Close mobile menu after navigation
          this.closeMobileMenu();
        }
      });
    }

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

  /**
   * Lazy load external services module (dynamic import)
   * Only loads when user navigates to external services page
   */
  async loadExternalServices() {
    try {
      console.log('[Dashboard] Loading external services (lazy load triggered)');
      
      // If already loaded, just initialize
      if (this.externalServices) {
        console.log('[Dashboard] External services already loaded, reinitializing...');
        await this.externalServices.init();
        return;
      }

      console.log('[Dashboard] Importing external services module...');
      // Dynamic import - only loads when needed
            const { ExternalServicesManager } = await import('./external-services/external-services.js?v=2025.12.01.1');
      
      console.log('[Dashboard] Creating ExternalServicesManager instance...');
      // Create instance and initialize
      this.externalServices = new ExternalServicesManager(
        '#external-services-grid',
        '#external-services-settings'
      );
      
      console.log('[Dashboard] Initializing external services...');
      await this.externalServices.init();
      console.log('[Dashboard] External services loaded successfully');
    } catch (error) {
      console.error('[Dashboard] Failed to load external services:', error);
      this.showError('Failed to load external services. Please try again.');
    }
  }
    
  hideLoadingScreen() {
    // Hide loading screen immediately - cards now appear instantly with async loading
    const loadingScreen = document.getElementById("loading-screen");
    const dashboard = document.getElementById("dashboard");

    if (loadingScreen && dashboard) {
      loadingScreen.style.display = "none";
      dashboard.style.display = "flex";
    }
  }

  toggleMobileMenu() {
    const sidebar = document.querySelector(".sidebar");
    if (sidebar) {
      const isOpening = !sidebar.classList.contains("mobile-open");
      sidebar.classList.toggle("mobile-open");
      
      // Manage focus when menu opens/closes
      if (isOpening) {
        this.setupMobileFocusTrap(sidebar);
      } else {
        this.removeMobileFocusTrap();
        // Return focus to toggle button
        const mobileToggle = document.getElementById("mobile-menu-toggle");
        if (mobileToggle) mobileToggle.focus();
      }
    }
  }

  closeMobileMenu() {
    const sidebar = document.querySelector(".sidebar");
    if (sidebar) {
      sidebar.classList.remove("mobile-open");
      this.removeMobileFocusTrap();
      // Return focus to toggle button
      const mobileToggle = document.getElementById("mobile-menu-toggle");
      if (mobileToggle) mobileToggle.focus();
    }
  }

  /**
   * Set up focus trap for mobile menu accessibility
   * Prevents focus from escaping the menu overlay when open
   */
  setupMobileFocusTrap(sidebar) {
    // Get all focusable elements in sidebar
    const focusableSelector = 'a[href], button, [tabindex]:not([tabindex="-1"])';
    const focusableElements = sidebar.querySelectorAll(focusableSelector);
    
    if (focusableElements.length === 0) return;
    
    this.firstFocusable = focusableElements[0];
    this.lastFocusable = focusableElements[focusableElements.length - 1];
    
    // Focus first element when menu opens
    this.firstFocusable.focus();
    
    // Store bound handler for removal
    this.focusTrapHandler = (e) => {
      if (e.key !== 'Tab') return;
      
      if (e.shiftKey) {
        // Shift+Tab: if on first element, wrap to last
        if (document.activeElement === this.firstFocusable) {
          e.preventDefault();
          this.lastFocusable.focus();
        }
      } else {
        // Tab: if on last element, wrap to first
        if (document.activeElement === this.lastFocusable) {
          e.preventDefault();
          this.firstFocusable.focus();
        }
      }
    };
    
    document.addEventListener('keydown', this.focusTrapHandler);
  }

  /**
   * Remove focus trap when mobile menu closes
   */
  removeMobileFocusTrap() {
    if (this.focusTrapHandler) {
      document.removeEventListener('keydown', this.focusTrapHandler);
      this.focusTrapHandler = null;
    }
    this.firstFocusable = null;
    this.lastFocusable = null;
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
    const serverTimeElement = document.getElementById("server-time");
    
    // Early return if element doesn't exist (prevents errors)
    if (!serverTimeElement) {
      return;
    }
    
    const updateClock = () => {
      const now = new Date();
      const timeString = now.toLocaleTimeString("en-US", {
        hour12: false,
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });

      // Use cached element reference instead of getElementById
      serverTimeElement.textContent = timeString;
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
    // Log current page being refreshed
    const currentPage = this.state.getCurrentPage();
    console.log('[Dashboard] Auto-refresh triggered for page:', currentPage);
    
    // Clear service cache on manual refresh
    this.state.clearServiceCache();
    this.showRefreshAnimation();
    this.loadPageData(currentPage);
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

  /**
   * Show skeleton loading state for sites using DocumentFragment
   * Avoids forced DOM reparse from innerHTML
   */
  showSkeletonSites() {
    const sitesGrid = document.getElementById("sites-grid");
    if (sitesGrid) {
      sitesGrid.textContent = ''; // Clear efficiently
      const fragment = document.createDocumentFragment();
      
      for (let i = 0; i < 3; i++) {
        const card = document.createElement('div');
        card.className = 'skeleton-card';
        
        const title = document.createElement('div');
        title.className = 'skeleton skeleton-title';
        card.appendChild(title);
        
        const text1 = document.createElement('div');
        text1.className = 'skeleton skeleton-text';
        card.appendChild(text1);
        
        const text2 = document.createElement('div');
        text2.className = 'skeleton skeleton-text short';
        card.appendChild(text2);
        
        fragment.appendChild(card);
      }
      
      sitesGrid.appendChild(fragment);
    }
  }

  /**
   * Show skeleton loading state for system info using DocumentFragment
   * Avoids forced DOM reparse from innerHTML
   */
  showSkeletonSystemInfo() {
    const systemInfo = document.getElementById("system-info");
    if (systemInfo) {
      systemInfo.textContent = ''; // Clear efficiently
      const fragment = document.createDocumentFragment();
      
      for (let i = 0; i < 3; i++) {
        const text = document.createElement('div');
        text.className = 'skeleton skeleton-text';
        fragment.appendChild(text);
      }
      
      systemInfo.appendChild(fragment);
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
    

  isValidSite(site) {
    return this.utils.isValidSite(site);
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
      
      if (summary.enabled) {
        const totalCount = this.normalizeMonitorCount(summary.total_monitors);
        const upCount = this.normalizeMonitorCount(summary.up);
        const downCount = this.normalizeMonitorCount(summary.down);

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
      
      if (!response.enabled) {
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
    
    // API returns 'status' (numeric) and 'status_text' (string)
    const statusClass = this.getUptimeStatusClass(monitor.status);
    
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
    
    // API returns uptime_day, uptime_week, uptime_month (use day for display)
    const uptimeRatio = monitor.uptime_day || monitor.uptime_week || monitor.uptime_month || 0;
    const hasStats = uptimeRatio > 0 || monitor.response_time > 0;
    
    if (hasStats) {
      const statsDiv = document.createElement("div");
      statsDiv.className = "monitor-stats";
      
      if (uptimeRatio > 0) {
        const uptimeStatDiv = document.createElement("div");
        uptimeStatDiv.className = "stat";
        
        const uptimeValue = document.createElement("span");
        uptimeValue.className = "stat-value";
        uptimeValue.textContent = this.sanitizeNumeric(uptimeRatio, "0") + "%";
        
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
    // API returns 'status_text' for the text version
    statusText.textContent = this.sanitizeInput(monitor.status_text || 'Unknown');
    
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
