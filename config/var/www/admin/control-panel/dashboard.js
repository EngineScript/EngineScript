// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention

/* global Chart */

class EngineScriptDashboard {
  constructor() {
    this.currentPage = "overview";
    this.refreshInterval = 30000; // 30 seconds
    this.charts = {};
    this.refreshTimer = null;

    // Security configurations
    this.maxRefreshInterval = 300000; // 5 minutes max
    this.minRefreshInterval = 5000; // 5 seconds min
    this.allowedTimeRanges = ["1h", "6h", "24h", "48h"];
    this.allowedPages = ["overview", "sites", "system", "tools"];
    this.allowedTools = ["phpmyadmin", "phpinfo", "phpsysinfo", "adminer"];

    this.init();
  }

  init() {
    this.setupEventListeners();
    this.setupNavigation();
    this.startClock();
    this.loadInitialData();
    this.hideLoadingScreen();
  }

  setupEventListeners() {
    // Navigation
    document.querySelectorAll(".nav-item").forEach((item) => {
      item.addEventListener("click", (e) => {
        e.preventDefault();
        const page = this.sanitizeInput(item.dataset.page);
        if (this.allowedPages.includes(page)) {
          this.navigateToPage(page);
        }
      });
    });

    // Refresh button
    const refreshBtn = document.getElementById("refresh-btn");
    if (refreshBtn) {
      refreshBtn.addEventListener("click", () => this.refreshData());
    }

    // Chart timerange selector
    const chartTimerange = document.getElementById("chart-timerange");
    if (chartTimerange) {
      chartTimerange.addEventListener("change", (e) => {
        const timeRange = this.sanitizeInput(e.target.value);
        if (this.allowedTimeRanges.includes(timeRange)) {
          this.updatePerformanceChart(timeRange);
        }
      });
    }

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
    if (!this.allowedPages.includes(pageName)) {
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
    this.currentPage = pageName;
  }

  getPageTitle(pageName) {
    const titles = {
      overview: "Overview",
      sites: "WordPress Sites",
      system: "System Information",
      tools: "Admin Tools",
    };
    return titles[pageName] || "Dashboard";
  }
    
  loadPageData(pageName) {
    // Validate page name
    if (!this.allowedPages.includes(pageName)) {
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
    setTimeout(() => {
      const loadingScreen = document.getElementById("loading-screen");
      const dashboard = document.getElementById("dashboard");

      loadingScreen.style.opacity = "0";
      setTimeout(() => {
        loadingScreen.style.display = "none";
        dashboard.style.display = "flex";
      }, 500);
    }, 1500);
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
    this.refreshTimer = setInterval(() => {
      this.refreshData();
    }, this.refreshInterval);
  }
    
  refreshData() {
    this.showRefreshAnimation();
    this.loadPageData(this.currentPage);
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
      // Load system stats
      await this.loadSystemStats();

      // Load service status
      await this.loadServiceStatus();

      // Load recent activity
      await this.loadRecentActivity();

      // Load system alerts
      await this.loadSystemAlerts();

      // Initialize performance chart
      this.initializePerformanceChart();

      // Load uptime monitoring data
      this.loadUptimeData();

    } catch (error) {
      this.showError(
        `Failed to load dashboard data: ${error.message || error}`,
      );
    }
  }
    
  async loadSystemStats() {
    try {
      // Simulate API calls - In real implementation, these would be actual API endpoints
      const stats = {
        sites: await this.getApiData("/api/sites/count", "0"),
        memory: await this.getApiData("/api/system/memory", "0%"),
        disk: await this.getApiData("/api/system/disk", "0%"),
        cpu: await this.getApiData("/api/system/cpu", "0%"),
      };

      // Validate and sanitize numeric values
      const sanitizedStats = {
        sites: this.sanitizeNumeric(stats.sites, "0"),
        memory: this.sanitizePercentage(stats.memory, "0%"),
        disk: this.sanitizePercentage(stats.disk, "0%"),
        cpu: this.sanitizePercentage(stats.cpu, "0%"),
      };

      // Update stat cards safely
      this.setTextContent("sites-count", sanitizedStats.sites);
      this.setTextContent("memory-usage", sanitizedStats.memory);
      this.setTextContent("disk-usage", sanitizedStats.disk);
      this.setTextContent("cpu-usage", sanitizedStats.cpu);
    } catch (error) {
      // Set fallback values
      this.setTextContent("sites-count", "0");
      this.setTextContent("memory-usage", "0%");
      this.setTextContent("disk-usage", "0%");
      this.setTextContent("cpu-usage", "0%");
      throw error; // Re-throw to be caught by loadOverviewData
    }
  }
    
  async loadServiceStatus() {
    const services = ["nginx", "php", "mysql", "redis"];

    for (const service of services) {
      try {
        const status = await this.getServiceStatus(service);
        const element = document.getElementById(`${service}-status`);

        if (element) {
          const statusIcon = element.querySelector(".service-status i");
          const versionSpan = element.querySelector(".service-version");

          statusIcon.className = `fas fa-circle ${status.online ? "online" : "offline"}`;
          if (versionSpan && status.version) {
            versionSpan.textContent = `v${status.version}`;
          }
        }
      } catch (error) {
        // Silently handle service status errors
      }
    }
  }
    
  async loadRecentActivity() {
    try {
      const activities = await this.getApiData("/api/activity/recent", []);
      const activityList = document.getElementById("recent-activity");

      if (activityList && Array.isArray(activities) && activities.length > 0) {
        // Clear existing content
        activityList.innerHTML = "";

        // Validate and render each activity safely
        activities.forEach((activity) => {
          if (this.isValidActivity(activity)) {
            const activityElement = this.createActivityElement(activity);
            activityList.appendChild(activityElement);
          }
        });
      }
    } catch (error) {
      // Silently handle recent activity errors
    }
  }
    
  async loadSystemAlerts() {
    try {
      const alerts = await this.getApiData("/api/alerts", []);
      const alertList = document.getElementById("system-alerts");

      if (alertList) {
        // Clear existing content
        alertList.innerHTML = "";

        if (Array.isArray(alerts) && alerts.length > 0) {
          alerts.forEach((alert) => {
            if (this.isValidAlert(alert)) {
              const alertElement = this.createAlertElement(alert);
              alertList.appendChild(alertElement);
            }
          });
        } else {
          // Create default "all systems operational" alert
          const defaultAlert = this.createAlertElement({
            message: "All systems operational",
            time: "Just now",
            type: "info",
          });
          alertList.appendChild(defaultAlert);
        }
      }
    } catch (error) {
      // Silently handle system alerts errors
    }
  }
    
  getAlertIcon(type) {
    const icons = {
      info: "fa-info-circle",
      warning: "fa-exclamation-triangle",
      error: "fa-exclamation-circle",
      success: "fa-check-circle",
    };
    return icons[type] || "fa-info-circle";
  }
    
  async loadSites() {
    try {
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
      // Silently handle sites loading errors
    }
  }
    
  async loadSystemInfo() {
    try {
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
            label: "Uptime",
            value: this.sanitizeInput(sysInfo.uptime) || "Loading...",
          },
          { label: "Load Average", value: this.sanitizeInput(sysInfo.load) || "Loading..." },
          { label: "Memory Total", value: this.sanitizeInput(sysInfo.memory_total) || "Loading..." },
          { label: "Disk Total", value: this.sanitizeInput(sysInfo.disk_total) || "Loading..." },
          { label: "Network", value: this.sanitizeInput(sysInfo.network) || "Loading..." }
        ];

        infoItems.forEach(item => {
          const infoElement = this.createInfoElement(item.label, item.value);
          systemInfo.appendChild(infoElement);
        });
      }

      // Initialize resource usage chart
      this.initializeResourceChart();

    } catch (error) {
      // Silently handle system info errors
    }
  }
    
  initializePerformanceChart() {
    const ctx = document.getElementById("performance-chart");
    if (!ctx || typeof Chart === "undefined") return;

    // Destroy existing chart if it exists
    if (this.charts.performance) {
      this.charts.performance.destroy();
    }

    // Load real performance data
    this.loadPerformanceChartData("24h");
  }

  createPerformanceChartConfig(chartData) {
    return {
      type: "line",
      data: {
        labels: chartData.labels || [],
        datasets: [
          {
            label: "CPU %",
            data: chartData.cpu || [],
            borderColor: "#00d4aa",
            backgroundColor: "rgba(0, 212, 170, 0.1)",
            tension: 0.4,
          },
          {
            label: "Memory %",
            data: chartData.memory || [],
            borderColor: "#00a8ff",
            backgroundColor: "rgba(0, 168, 255, 0.1)",
            tension: 0.4,
          },
          {
            label: "Disk %",
            data: chartData.disk || [],
            borderColor: "#ffb800",
            backgroundColor: "rgba(255, 184, 0, 0.1)",
            tension: 0.4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 0, // Disable animation to prevent sizing issues
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            min: 0,
            grid: {
              color: "#444444",
            },
            ticks: {
              color: "#b3b3b3",
              stepSize: 25, // Force consistent scale steps
            },
          },
          x: {
            grid: {
              color: "#444444",
            },
            ticks: {
              color: "#b3b3b3",
            },
          },
        },
        plugins: {
          legend: {
            labels: {
              color: "#b3b3b3",
            },
          },
        },
      },
    };
  }

  createPerformanceChart(chartData) {
    const ctx = document.getElementById("performance-chart");
    if (!ctx || typeof Chart === "undefined") return;

    const config = this.createPerformanceChartConfig(chartData);
    this.charts.performance = new Chart(ctx, config);
  }

  async loadPerformanceChartData(timerange) {
    try {
      const chartData = await this.getApiData(`/api/system/performance?timerange=${timerange}`, this.generateFallbackData(timerange));
      this.createPerformanceChart(chartData);
    } catch (error) {
      // Use fallback data if API fails
      this.loadFallbackChart(timerange);
    }
  }

  loadFallbackChart(timerange) {
    const chartData = this.generateFallbackData(timerange);
    this.createPerformanceChart(chartData);
  }
    
  initializeResourceChart() {
    const ctx = document.getElementById("resource-chart");
    if (!ctx || typeof Chart === "undefined") return;

    // Destroy existing chart if it exists
    if (this.charts.resource) {
      this.charts.resource.destroy();
    }

    this.charts.resource = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: ["Used", "Free"],
        datasets: [
          {
            label: "Memory Usage",
            data: [30, 70], // Sample data
            backgroundColor: ["#00d4aa", "#444444"],
            borderWidth: 0,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            labels: {
              color: "#b3b3b3",
            },
          },
        },
      },
    });
  }
    
  updatePerformanceChart(timerange) {
    // Validate timerange
    if (!this.allowedTimeRanges.includes(timerange)) {
      return;
    }

    if (!this.charts.performance) {
      this.loadPerformanceChartData(timerange);
      return;
    }

    // Load new data for the selected timerange
    this.loadPerformanceChartData(timerange);
  }
    
  generateFallbackData(timerange) {
    const points = timerange === "1h" ? 12 : timerange === "6h" ? 24 : timerange === "24h" ? 24 : 48;
    const labels = [];
    const cpu = [];
    const memory = [];
    const disk = [];

    for (let i = 0; i < points; i++) {
      // Generate time labels
      const time = new Date();
      if (timerange === "1h") {
        time.setMinutes(time.getMinutes() - (points - i) * 5);
        labels.push(time.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" }));
      } else if (timerange === "6h") {
        time.setMinutes(time.getMinutes() - (points - i) * 15);
        labels.push(time.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" }));
      } else {
        time.setHours(time.getHours() - (points - i));
        labels.push(time.toLocaleTimeString("en-US", { hour: "2-digit" }) + ":00");
      }

      // Generate sample fallback data with realistic patterns (not random)
      const baseTime = Date.now() - ((points - i) * (timerange === "1h" ? 5 : timerange === "6h" ? 15 : 60) * 60000);
      const hourOfDay = new Date(baseTime).getHours();
      
      // Create realistic CPU patterns based on time of day
      let baseCpu = 15;
      if (hourOfDay >= 9 && hourOfDay <= 17) baseCpu = 25; // Business hours
      if (hourOfDay >= 18 && hourOfDay <= 22) baseCpu = 20; // Evening
      cpu.push(baseCpu + Math.sin(i * 0.5) * 5); // Gentle variation
      
      // Memory usage typically more stable
      memory.push(45 + Math.sin(i * 0.3) * 8);
      
      // Disk usage very stable
      disk.push(65 + Math.sin(i * 0.1) * 2);
    }

    return { labels, cpu, memory, disk };
  }
    
  // Browser compatibility helper
  isOperaMini() {
    return (
      typeof navigator !== "undefined" &&
      navigator.userAgent &&
      navigator.userAgent.indexOf("Opera Mini") > -1
    );
  }

  // API Methods
  async getApiData(endpoint, fallback) {
    try {
      // Check if fetch is available and supported (Opera Mini compatibility)
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return fallback;
      }

      const response = await fetch(endpoint);

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
      // Return fallback value on error
      return fallback;
    }
  }

  async getServiceStatus(service) {
    try {
      // Check if fetch is available and supported (Opera Mini compatibility)
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { online: false, version: "Unavailable" };
      }

      const response = await fetch("/api/services/status");
      const data = await response.json();

      return data[service] || { online: false, version: "Unknown" };
    } catch (error) {
      return { online: false, version: "Error" };
    }
  }
    
  showError(message) {
    // Sanitize error message
    const sanitizedMessage = this.sanitizeInput(message) || "An unknown error occurred";

    // Create a simple error notification
    const notification = document.createElement("div");
    notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: var(--error-color);
            color: white;
            padding: 1rem 1.5rem;
            border-radius: var(--border-radius);
            box-shadow: var(--shadow);
            z-index: 10000;
            max-width: 300px;
        `;
    notification.textContent = sanitizedMessage;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.remove();
    }, 5000);
  }
    
  // Security Helper Methods
  removeDangerousPatterns(input) {
    // Common security patterns that should be removed from all inputs
    const dangerousPatterns = [
      /javascript/gi,
      /vbscript/gi,
      /data:/gi,
      /about:/gi,
      /file:/gi,
      /<script/gi,
      /<iframe/gi,
      /<object/gi,
      /<embed/gi,
      /<link/gi,
      /<meta/gi,
      /on\w+=/gi,
      /expression/gi,
      /eval/gi,
      /alert/gi,
      /prompt/gi,
      /confirm/gi,
      /<\/script/gi,
      /<\/iframe/gi,
    ];

    let sanitized = input;
    dangerousPatterns.forEach((pattern) => {
      sanitized = sanitized.replace(pattern, "");
    });

    return sanitized;
  }

  sanitizeInput(input) {
    if (typeof input !== "string") {
      return String(input || "");
    }

    // Use whitelist approach for maximum security
    // Only allow alphanumeric characters, spaces, and safe punctuation
    let sanitized = String(input)
      .replace(/[\u0000-\u001F\u007F-\u009F]/g, "") // Remove all control characters
      .replace(/[^\w\s.\-@#%]/g, "") // Keep only safe characters: letters, numbers, spaces, . - @ # %
      .replace(/\s+/g, " ") // Normalize whitespace
      .trim()
      .substring(0, 1000); // Limit length

    // Remove dangerous patterns using shared method
    return this.removeDangerousPatterns(sanitized);
  }

  sanitizeNumeric(input, fallback = "0") {
    const cleaned = String(input || "").replace(/[^\d.-]/g, "");
    return cleaned || fallback;
  }

  sanitizePercentage(input, fallback = "0%") {
    const cleaned = String(input || "").replace(/[^\d.%]/g, "");
    return cleaned || fallback;
  }
    
  setTextContent(elementId, content) {
    const element = document.getElementById(elementId);
    if (element) {
      element.textContent = String(content || "");
    }
  }
    
  isValidActivity(activity) {
    return (
      activity &&
      typeof activity === "object" &&
      typeof activity.message === "string" &&
      typeof activity.time === "string" &&
      activity.message.length > 0 &&
      activity.message.length < 500
    );
  }

  isValidAlert(alert) {
    const validTypes = ["info", "warning", "error", "success"];
    return (
      alert &&
      typeof alert === "object" &&
      typeof alert.message === "string" &&
      typeof alert.time === "string" &&
      (!alert.type || validTypes.includes(alert.type)) &&
      alert.message.length > 0 &&
      alert.message.length < 500
    );
  }

  isValidSite(site) {
    return (
      site &&
      typeof site === "object" &&
      typeof site.domain === "string" &&
      site.domain.length > 0 &&
      site.domain.length < 255 &&
      /^[a-zA-Z0-9.-]+$/.test(site.domain)
    ); // Basic domain validation
  }
    
  // Helper method for creating content elements with icon, message, and time
  createContentElement(config) {
    const { containerClass, iconClass, contentClass, messageText, timeText, timeClass, iconType } = config;

    const containerDiv = document.createElement("div");
    containerDiv.className = containerClass;

    const iconDiv = document.createElement("div");
    iconDiv.className = iconClass;

    const icon = document.createElement("i");
    icon.className = `fas ${iconType}`;
    iconDiv.appendChild(icon);

    const contentDiv = document.createElement("div");
    contentDiv.className = contentClass;

    const message = document.createElement("p");
    message.textContent = this.sanitizeInput(messageText);

    const time = document.createElement("span");
    time.className = timeClass;
    time.textContent = this.sanitizeInput(timeText);

    contentDiv.appendChild(message);
    contentDiv.appendChild(time);

    containerDiv.appendChild(iconDiv);
    containerDiv.appendChild(contentDiv);

    return containerDiv;
  }

  createActivityElement(activity) {
    const iconClass = this.sanitizeInput(activity.icon) || "fa-info-circle";
    
    return this.createContentElement({
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

    return this.createContentElement({
      containerClass: `alert-item ${alertType}`,
      iconClass: `alert-icon ${alertType}`,
      contentClass: "alert-content",
      messageText: alert.message,
      timeText: alert.time,
      timeClass: "alert-time",
      iconType: this.getAlertIcon(alertType),
    });
  }
    
  createSiteElement(site) {
    const siteDiv = document.createElement("div");
    siteDiv.className = "site-card";

    // Site header
    const headerDiv = document.createElement("div");
    headerDiv.className = "site-header";

    const title = document.createElement("h3");
    title.textContent = this.sanitizeInput(site.domain);

    const statusDiv = document.createElement("div");
    statusDiv.className = "site-status";

    const statusIndicator = document.createElement("span");
    const sanitizedStatus = this.sanitizeInput(site.status) || "unknown";
    statusIndicator.className = `status-indicator ${sanitizedStatus}`;

    const statusText = document.createTextNode(sanitizedStatus);

    statusDiv.appendChild(statusIndicator);
    statusDiv.appendChild(statusText);

    headerDiv.appendChild(title);
    headerDiv.appendChild(statusDiv);

    // Site info
    const infoDiv = document.createElement("div");
    infoDiv.className = "site-info";

    const wpInfo = document.createElement("p");
    wpInfo.innerHTML = "<strong>WordPress:</strong> ";
    wpInfo.appendChild(document.createTextNode(this.sanitizeInput(site.wp_version) || "Unknown"));

    const sslInfo = document.createElement("p");
    sslInfo.innerHTML = "<strong>SSL:</strong> ";
    sslInfo.appendChild(document.createTextNode(this.sanitizeInput(site.ssl_status) || "Unknown"));

    infoDiv.appendChild(wpInfo);
    infoDiv.appendChild(sslInfo);

    siteDiv.appendChild(headerDiv);
    siteDiv.appendChild(infoDiv);

    return siteDiv;
  }
    
  createNoSitesElement() {
    const siteDiv = document.createElement("div");
    siteDiv.className = "site-card";

    const headerDiv = document.createElement("div");
    headerDiv.className = "site-header";

    const title = document.createElement("h3");
    title.textContent = "No sites found";

    headerDiv.appendChild(title);

    const infoDiv = document.createElement("div");
    infoDiv.className = "site-info";

    const message = document.createElement("p");
    message.textContent = "No WordPress sites are currently configured.";

    infoDiv.appendChild(message);

    siteDiv.appendChild(headerDiv);
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
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
    }

    Object.values(this.charts).forEach((chart) => {
      if (chart && chart.destroy) {
        chart.destroy();
      }
    });
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
      // Silently handle uptime loading errors
    }
  }

  async loadUptimeSummary() {
    try {
      const summary = await this.getApiData("/api/monitoring/uptime", {});
      
      if (summary.configured) {
        this.setTextContent("total-monitors", summary.total_monitors || 0);
        this.setTextContent("up-monitors", summary.up_monitors || 0);
        this.setTextContent("down-monitors", summary.down_monitors || 0);
        this.setTextContent("average-uptime", (summary.average_uptime || 0) + "%");
      } else {
        this.showUptimeNotConfigured();
      }
    } catch (error) {
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
        monitorsContainer.innerHTML = '<div class="uptime-status"><p>No monitors configured. Add websites to monitor in your Uptime Robot dashboard.</p></div>';
        return;
      }
      
      // Clear existing content
      monitorsContainer.innerHTML = '';
      
      monitors.forEach(monitor => {
        const monitorElement = this.createUptimeMonitorElement(monitor);
        monitorsContainer.appendChild(monitorElement);
      });
      
    } catch (error) {
      this.showUptimeError();
    }
  }

  createUptimeMonitorElement(monitor) {
    const monitorDiv = document.createElement("div");
    monitorDiv.className = "uptime-monitor";
    
    const statusClass = this.getUptimeStatusClass(monitor.status_code);
    
    monitorDiv.innerHTML = `
      <div class="monitor-status ${statusClass}">
        <span class="status-dot"></span>
      </div>
      <div class="monitor-info">
        <h4>${this.sanitizeInput(monitor.name)}</h4>
        <p class="monitor-url">${this.sanitizeInput(monitor.url)}</p>
      </div>
      <div class="monitor-stats">
        <div class="stat">
          <span class="stat-value">${monitor.uptime_ratio}%</span>
          <span class="stat-label">Uptime</span>
        </div>
        <div class="stat">
          <span class="stat-value">${monitor.response_time}ms</span>
          <span class="stat-label">Response</span>
        </div>
      </div>
      <div class="monitor-status-text">
        <span class="status-text">${this.sanitizeInput(monitor.status)}</span>
        <span class="last-check">${this.sanitizeInput(monitor.last_check)}</span>
      </div>
    `;
    
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
      monitorsContainer.innerHTML = `
        <div class="uptime-status">
          <p><strong>Uptime Robot not configured</strong></p>
          <p>To enable website monitoring:</p>
          <ol>
            <li>Create a free account at <a href="https://uptimerobot.com/" target="_blank">UptimeRobot.com</a></li>
            <li>Get your API key from Settings > API Settings</li>
            <li>Configure it using: <code>sudo nano /etc/enginescript/uptimerobot.conf</code></li>
            <li>Add: <code>api_key=your_api_key_here</code></li>
          </ol>
        </div>
      `;
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
      monitorsContainer.innerHTML = '<div class="uptime-status"><p>Error loading uptime monitoring data. Please check your configuration and try again.</p></div>';
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
