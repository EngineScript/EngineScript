// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention

/* global Chart */

import { DashboardAPI } from './modules/api.js?v=2025.11.10.3';
import { DashboardState } from './modules/state.js?v=2025.11.10.3';
import { DashboardCharts } from './modules/charts.js?v=2025.11.10.3';
import { DashboardUtils } from './modules/utils.js?v=2025.11.10.3';

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

    // Uptime refresh button
    const uptimeRefreshBtn = document.getElementById("uptime-refresh-btn");
    if (uptimeRefreshBtn) {
      uptimeRefreshBtn.addEventListener("click", () => this.loadUptimeData());
    }
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

      // Number keys 1-4 - Quick page navigation
      if (event.key >= "1" && event.key <= "4" && !event.ctrlKey && !event.altKey && !event.shiftKey) {
        const pages = ["overview", "sites", "system", "tools"];
        const pageIndex = parseInt(event.key) - 1;
        if (pageIndex < pages.length) {
          this.navigateToPage(pages[pageIndex]);
        }
      }
    });
  }

  navigateWithKeys(forward) {
    const pages = ["overview", "sites", "system", "tools"];
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
    
  async loadSystemAlerts() {
    return this.utils.getAlertIcon(type);
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
        this.setTextContent("total-monitors", summary.total_monitors || 0);
        this.setTextContent("up-monitors", summary.up_monitors || 0);
        // Explicitly show 0 for offline (down_monitors)
        const downCount = summary.down_monitors !== undefined ? summary.down_monitors : 0;
        this.setTextContent("down-monitors", downCount);
        this.setTextContent("average-uptime", (summary.average_uptime || 0) + "%");
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
    this.setTextContent("down-monitors", "--");
    this.setTextContent("average-uptime", "--%");
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
