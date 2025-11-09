// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention

/* global Chart */

class EngineScriptDashboard {
  constructor() {
    this.currentPage = "overview";
    this.refreshInterval = 30000; // 30 seconds
    this.charts = {};
    this.refreshTimer = null;
    this.csrfToken = null; // CSRF token for future state-changing requests

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
    this.loadCsrfToken(); // Load CSRF token before other API calls
    this.loadInitialData();
    this.hideLoadingScreen();
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
        if (this.allowedPages.includes(page)) {
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
      // Show skeleton loaders while loading
      this.showSkeletonStats();
      this.showSkeletonServiceStatus();
      this.showSkeletonActivityList();
      this.showSkeletonAlerts();
      this.showSkeletonChart("performance-chart-container");

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
      console.error('Failed to load system stats:', error);
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
        console.error(`Failed to load status for service ${service}:`, error);
        // Set fallback offline status
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
      }
    }
  }
    
  async loadRecentActivity() {
    try {
      const activities = await this.getApiData("/api/activity/recent", []);
      const activityList = document.getElementById("recent-activity");

      if (activityList) {
        if (Array.isArray(activities) && activities.length > 0) {
          // Clear existing content
          activityList.innerHTML = "";

          // Validate and render each activity safely
          activities.forEach((activity) => {
            if (this.isValidActivity(activity)) {
              const activityElement = this.createActivityElement(activity);
              activityList.appendChild(activityElement);
            }
          });
        } else {
          // Show empty state
          this.showEmptyActivity();
        }
      }
    } catch (error) {
      console.error('Failed to load recent activity:', error);
      this.showEmptyActivity();
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
          // Show empty state for all systems operational
          this.showEmptyAlerts();
        }
      }
    } catch (error) {
      console.error('Failed to load system alerts:', error);
      this.showEmptyAlerts();
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
      console.error('Failed to load system information:', error);
      this.showErrorSystemInfo();
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
      console.error('Failed to load performance chart data:', error);
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
      // Return fallback value on error
      return fallback;
    }
  }

  async postApiData(endpoint, data = {}) {
    try {
      // Check if fetch is available
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
      // Check if fetch is available and supported (Opera Mini compatibility)
      if (typeof fetch === "undefined" || this.isOperaMini()) {
        return { online: false, version: "Unavailable" };
      }

      const response = await fetch("/api/services/status");
      const data = await response.json();

      return data[service] || { online: false, version: "Unknown" };
    } catch (error) {
      console.error(`Failed to get service status for ${service}:`, error);
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
      // codacy:ignore:javascript:S6443 - Control character removal is intentional for security sanitization
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
    const parsed = parseFloat(cleaned);
    
    // Check if it's a valid number and within reasonable bounds
    if (isNaN(parsed) || !isFinite(parsed)) {
      return fallback;
    }
    
    // Reasonable bounds for dashboard metrics
    if (parsed < 0 || parsed > 999999) {
      return fallback;
    }
    
    return cleaned || fallback;
  }

  sanitizePercentage(input, fallback = "0%") {
    const cleaned = String(input || "").replace(/[^\d.%]/g, "");
    return cleaned || fallback;
  }

  sanitizeUrl(input, fallback = "") {
    if (typeof input !== "string") {
      return fallback;
    }
    
    // Basic URL validation and sanitization
    const urlPattern = /^https?:\/\/[a-zA-Z0-9.-]+(?::\d+)?(?:\/\S*)?$/;
    const sanitized = String(input)
      // codacy:ignore:javascript:S6443 - Control character removal is intentional for security sanitization
      .replace(/[\u0000-\u001F\u007F-\u009F]/g, "") // Remove control characters
      .trim()
      .substring(0, 2048); // Limit URL length
    
    // Check if it matches basic URL pattern
    if (!urlPattern.test(sanitized)) {
      return fallback;
    }
    
    // Remove dangerous patterns
    return this.removeDangerousPatterns(sanitized);
  }
    
  setTextContent(elementId, content) {
    const element = document.getElementById(elementId);
    if (element) {
      element.textContent = String(content || "");
    }
  }

  // Skeleton loader helpers
  showSkeletonStat(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
      element.innerHTML = '<div class="skeleton skeleton-stat"></div>';
    }
  }

  showSkeletonStats() {
    this.showSkeletonStat("sites-count");
    this.showSkeletonStat("memory-usage");
    this.showSkeletonStat("disk-usage");
    this.showSkeletonStat("cpu-usage");
  }

  showSkeletonChart(chartContainerId) {
    const container = document.getElementById(chartContainerId);
    if (container) {
      container.innerHTML = '<div class="skeleton-chart"></div>';
    }
  }

  showSkeletonServiceStatus() {
    const services = ["nginx", "php", "mysql", "redis"];
    services.forEach(service => {
      const element = document.getElementById(`${service}-status`);
      if (element) {
        element.innerHTML = `
          <div class="skeleton-row">
            <div class="skeleton-circle"></div>
            <div style="flex: 1;">
              <div class="skeleton skeleton-text short"></div>
              <div class="skeleton skeleton-text short" style="width: 50%;"></div>
            </div>
          </div>
        `;
      }
    });
  }

  showSkeletonActivityList() {
    const activityList = document.getElementById("recent-activity");
    if (activityList) {
      let html = '';
      for (let i = 0; i < 3; i++) {
        html += `
          <div class="skeleton-card">
            <div class="skeleton skeleton-text short"></div>
            <div class="skeleton skeleton-text" style="width: 40%;"></div>
          </div>
        `;
      }
      activityList.innerHTML = html;
    }
  }

  showSkeletonAlerts() {
    const alertList = document.getElementById("system-alerts");
    if (alertList) {
      let html = '';
      for (let i = 0; i < 2; i++) {
        html += `
          <div class="skeleton-card">
            <div class="skeleton skeleton-text"></div>
            <div class="skeleton skeleton-text short"></div>
          </div>
        `;
      }
      alertList.innerHTML = html;
    }
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
      for (let i = 0; i < 8; i++) {
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

  showEmptyActivity() {
    const activityList = document.getElementById("recent-activity");
    if (activityList) {
      const emptyState = this.createEmptyState(
        'info',
        'history',
        'No Recent Activity',
        'Activity will appear here as the system runs'
      );
      activityList.innerHTML = '';
      activityList.appendChild(emptyState);
    }
  }

  showEmptyAlerts() {
    const alertList = document.getElementById("system-alerts");
    if (alertList) {
      const emptyState = this.createEmptyState(
        'success',
        'check-circle',
        'All Systems Operational',
        'No alerts at this time'
      );
      alertList.innerHTML = '';
      alertList.appendChild(emptyState);
    }
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
        this.setTextContent("down-monitors", summary.down_monitors || 0);
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
    
    const statsDiv = document.createElement("div");
    statsDiv.className = "monitor-stats";
    
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
    
    statsDiv.appendChild(uptimeStatDiv);
    statsDiv.appendChild(responseStatDiv);
    
    const statusTextDiv = document.createElement("div");
    statusTextDiv.className = "monitor-status-text";
    
    const statusText = document.createElement("span");
    statusText.className = "status-text";
    statusText.textContent = this.sanitizeInput(monitor.status);
    
    const lastCheck = document.createElement("span");
    lastCheck.className = "last-check";
    lastCheck.textContent = this.sanitizeInput(monitor.last_check);
    
    statusTextDiv.appendChild(statusText);
    statusTextDiv.appendChild(lastCheck);
    
    monitorDiv.appendChild(statusDiv);
    monitorDiv.appendChild(infoDiv);
    monitorDiv.appendChild(statsDiv);
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
