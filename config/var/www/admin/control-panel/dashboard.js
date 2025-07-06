// EngineScript Admin Dashboard - Modern JavaScript
// Security-hardened version with input validation and XSS prevention
class EngineScriptDashboard {
  constructor() {
    this.currentPage = "overview";
    this.refreshInterval = 30000; // 30 seconds
    this.charts = {};
    this.refreshTimer = null;

    // Security configurations
    this.maxRefreshInterval = 300000; // 5 minutes max
    this.minRefreshInterval = 5000; // 5 seconds min
    this.allowedLogTypes = [
      "enginescript",
      "nginx",
      "php",
      "mysql",
      "redis",
      "system",
    ];
    this.allowedTimeRanges = ["1h", "6h", "24h", "48h"];
    this.allowedPages = ["overview", "sites", "system", "logs", "tools"];
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

    // Log type selector
    const logTypeSelect = document.getElementById("log-type");
    if (logTypeSelect) {
      logTypeSelect.addEventListener("change", (e) => {
        const logType = this.sanitizeInput(e.target.value);
        if (this.allowedLogTypes.includes(logType)) {
          this.loadLogs(logType);
        }
      });
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
      logs: "System Logs",
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
      case "logs":
        this.loadLogs("enginescript");
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
        cpu: await this.getApiData("/api/system/cpu", "0%")
      };

      // Validate and sanitize numeric values
      const sanitizedStats = {
        sites: this.sanitizeNumeric(stats.sites, '0'),
        memory: this.sanitizePercentage(stats.memory, '0%'),
        disk: this.sanitizePercentage(stats.disk, '0%'),
        cpu: this.sanitizePercentage(stats.cpu, '0%')
      };

      // Update stat cards safely
      this.setTextContent('sites-count', sanitizedStats.sites);
      this.setTextContent('memory-usage', sanitizedStats.memory);
      this.setTextContent('disk-usage', sanitizedStats.disk);
      this.setTextContent('cpu-usage', sanitizedStats.cpu);
    } catch (error) {
      // Set fallback values
      this.setTextContent('sites-count', '0');
      this.setTextContent('memory-usage', '0%');
      this.setTextContent('disk-usage', '0%');
      this.setTextContent('cpu-usage', '0%');
      throw error; // Re-throw to be caught by loadOverviewData
    }
  }
    
  async loadServiceStatus() {
    const services = ['nginx', 'php', 'mysql', 'redis'];

    for (const service of services) {
      try {
        const status = await this.getServiceStatus(service);
        const element = document.getElementById(`${service}-status`);

        if (element) {
          const statusIcon = element.querySelector('.service-status i');
          const versionSpan = element.querySelector('.service-version');

          statusIcon.className = `fas fa-circle ${status.online ? 'online' : 'offline'}`;
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
      const activities = await this.getApiData('/api/activity/recent', []);
      const activityList = document.getElementById('recent-activity');

      if (activityList && Array.isArray(activities) && activities.length > 0) {
        // Clear existing content
        activityList.innerHTML = '';

        // Validate and render each activity safely
        activities.forEach(activity => {
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
      const alerts = await this.getApiData('/api/alerts', []);
      const alertList = document.getElementById('system-alerts');

      if (alertList) {
        // Clear existing content
        alertList.innerHTML = '';

        if (Array.isArray(alerts) && alerts.length > 0) {
          alerts.forEach(alert => {
            if (this.isValidAlert(alert)) {
              const alertElement = this.createAlertElement(alert);
              alertList.appendChild(alertElement);
            }
          });
        } else {
          // Create default "all systems operational" alert
          const defaultAlert = this.createAlertElement({
            message: 'All systems operational',
            time: 'Just now',
            type: 'info'
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
      'info': 'fa-info-circle',
      'warning': 'fa-exclamation-triangle',
      'error': 'fa-exclamation-circle',
      'success': 'fa-check-circle'
    };
    return icons[type] || 'fa-info-circle';
  }
    
  async loadSites() {
    try {
      const sites = await this.getApiData('/api/sites', []);
      const sitesGrid = document.getElementById('sites-grid');

      if (sitesGrid) {
        // Clear existing content
        sitesGrid.innerHTML = '';

        if (Array.isArray(sites) && sites.length > 0) {
          sites.forEach(site => {
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
      const sysInfo = await this.getApiData('/api/system/info', {});
      const systemInfo = document.getElementById('system-info');

      if (systemInfo && typeof sysInfo === 'object') {
        // Clear existing content
        systemInfo.innerHTML = '';

        const infoItems = [
          { label: 'OS', value: this.sanitizeInput(sysInfo.os) || 'Ubuntu 24.04 LTS' },
          { label: 'Kernel', value: this.sanitizeInput(sysInfo.kernel) || 'Loading...' },
          { label: 'Uptime', value: this.sanitizeInput(sysInfo.uptime) || 'Loading...' },
          { label: 'Load Average', value: this.sanitizeInput(sysInfo.load) || 'Loading...' },
          { label: 'Memory Total', value: this.sanitizeInput(sysInfo.memory_total) || 'Loading...' },
          { label: 'Disk Total', value: this.sanitizeInput(sysInfo.disk_total) || 'Loading...' },
          { label: 'Network', value: this.sanitizeInput(sysInfo.network) || 'Loading...' }
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
    
  async loadLogs(logType) {
    // Validate log type
    if (!this.allowedLogTypes.includes(logType)) {
      return;
    }

    try {
      const logs = await this.getApiData(`/api/logs/${logType}`, '');
      const logViewer = document.getElementById('log-viewer');

      if (logViewer) {
        const pre = logViewer.querySelector('pre');
        if (pre) {
          // Sanitize and set log content as text (not HTML)
          const sanitizedLogs = this.sanitizeLogContent(logs) || `No ${logType} logs available.`;
          pre.textContent = sanitizedLogs;
        }
      }
    } catch (error) {
      // Silently handle log loading errors
    }
  }
    
    initializePerformanceChart() {
        const ctx = document.getElementById('performance-chart');
        if (!ctx) return;
        
        // Destroy existing chart if it exists
        if (this.charts.performance) {
            this.charts.performance.destroy();
        }
        
        const chartData = this.generateSampleData('24h');
        
        this.charts.performance = new Chart(ctx, {
            type: 'line',
            data: {
                labels: chartData.labels,
                datasets: [
                    {
                        label: 'CPU %',
                        data: chartData.cpu,
                        borderColor: '#00d4aa',
                        backgroundColor: 'rgba(0, 212, 170, 0.1)',
                        tension: 0.4
                    },
                    {
                        label: 'Memory %',
                        data: chartData.memory,
                        borderColor: '#00a8ff',
                        backgroundColor: 'rgba(0, 168, 255, 0.1)',
                        tension: 0.4
                    },
                    {
                        label: 'Disk %',
                        data: chartData.disk,
                        borderColor: '#ffb800',
                        backgroundColor: 'rgba(255, 184, 0, 0.1)',
                        tension: 0.4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#444444'
                        },
                        ticks: {
                            color: '#b3b3b3'
                        }
                    },
                    x: {
                        grid: {
                            color: '#444444'
                        },
                        ticks: {
                            color: '#b3b3b3'
                        }
                    }
                },
                plugins: {
                    legend: {
                        labels: {
                            color: '#b3b3b3'
                        }
                    }
                }
            }
        });
    }
    
    initializeResourceChart() {
        const ctx = document.getElementById('resource-chart');
        if (!ctx) return;
        
        // Destroy existing chart if it exists
        if (this.charts.resource) {
            this.charts.resource.destroy();
        }
        
        this.charts.resource = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Used', 'Free'],
                datasets: [
                    {
                        label: 'Memory Usage',
                        data: [30, 70], // Sample data
                        backgroundColor: ['#00d4aa', '#444444'],
                        borderWidth: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        labels: {
                            color: '#b3b3b3'
                        }
                    }
                }
            }
        });
    }
    
    updatePerformanceChart(timerange) {
        // Validate timerange
        if (!this.allowedTimeRanges.includes(timerange)) {
            return;
        }
        
        if (!this.charts.performance) return;
        
        const chartData = this.generateSampleData(timerange);
        this.charts.performance.data.labels = chartData.labels;
        this.charts.performance.data.datasets[0].data = chartData.cpu;
        this.charts.performance.data.datasets[1].data = chartData.memory;
        this.charts.performance.data.datasets[2].data = chartData.disk;
        this.charts.performance.update();
    }
    
    generateSampleData(timerange) {
        const points = timerange === '1h' ? 12 : timerange === '6h' ? 24 : timerange === '24h' ? 24 : 48;
        const labels = [];
        const cpu = [];
        const memory = [];
        const disk = [];
        
        for (let i = 0; i < points; i++) {
            // Generate time labels
            const time = new Date();
            if (timerange === '1h') {
                time.setMinutes(time.getMinutes() - (points - i) * 5);
                labels.push(time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }));
            } else if (timerange === '6h') {
                time.setMinutes(time.getMinutes() - (points - i) * 15);
                labels.push(time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }));
            } else {
                time.setHours(time.getHours() - (points - i));
                labels.push(time.toLocaleTimeString('en-US', { hour: '2-digit' }) + ':00');
            }
            
            // Generate sample data with some realistic patterns
            cpu.push(Math.random() * 30 + 10); // 10-40% CPU
            memory.push(Math.random() * 20 + 40); // 40-60% Memory
            disk.push(Math.random() * 10 + 70); // 70-80% Disk
        }
        
        return { labels, cpu, memory, disk };
    }
    
    // API Methods
    async getApiData(endpoint, fallback) {
        try {
            const response = await fetch(endpoint);
            
            if (!response.ok) {
                throw new Error(`API ${endpoint} returned ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            
            // Handle different response formats
            if (endpoint.includes('/system/memory') && data.usage) {
                return data.usage;
            }
            if (endpoint.includes('/system/disk') && data.usage) {
                return data.usage;
            }
            if (endpoint.includes('/system/cpu') && data.usage) {
                return data.usage;
            }
            if (endpoint.includes('/sites/count') && data.count !== undefined) {
                return data.count.toString();
            }
            
            return data;
        } catch (error) {
            throw new Error(`API call to ${endpoint} failed: ${error.message || error}`);
        }
    }
    
    async getServiceStatus(service) {
        try {
            const response = await fetch('/api/services/status');
            const data = await response.json();
            
            return data[service] || { online: false, version: 'Unknown' };
        } catch (error) {
            return { online: false, version: 'Error' };
        }
    }
    
    showError(message) {
        // Sanitize error message
        const sanitizedMessage = this.sanitizeInput(message) || 'An unknown error occurred';
        
        // Create a simple error notification
        const notification = document.createElement('div');
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
    sanitizeInput(input) {
        if (typeof input !== 'string') {
            return String(input || '');
        }
        
        // Use whitelist approach for maximum security
        // Only allow alphanumeric characters, spaces, and safe punctuation
        let sanitized = String(input)
            .replace(/[\x00-\x1F\x7F-\x9F]/g, '') // Remove all control characters
            .replace(/[^\w\s.\-_@#%]/g, '') // Keep only safe characters: letters, numbers, spaces, . - _ @ # %
            .replace(/\s+/g, ' ') // Normalize whitespace
            .trim()
            .substring(0, 1000); // Limit length
        
        // Additional security: remove any remaining dangerous patterns
        // This catches edge cases that might slip through the whitelist
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
            /confirm/gi
        ];
        
        dangerousPatterns.forEach(pattern => {
            sanitized = sanitized.replace(pattern, '');
        });
        
        return sanitized;
    }
    
    sanitizeNumeric(input, fallback = '0') {
        const cleaned = String(input || '').replace(/[^\d.-]/g, '');
        return cleaned || fallback;
    }
    
    sanitizePercentage(input, fallback = '0%') {
        const cleaned = String(input || '').replace(/[^\d.%]/g, '');
        return cleaned || fallback;
    }
    
    sanitizeLogContent(input) {
        if (typeof input !== 'string') {
            return '';
        }
        
        // For logs, we use whitelist approach but allow more characters for readability
        // Keep alphanumeric, spaces, line breaks, and common log punctuation
        let sanitized = String(input)
            .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, '') // Remove control chars but keep \t, \n, \r
            .replace(/[^\w\s.\-_@#%:\/\[\]\(\)\n\r\t]/g, '') // Keep safe chars + common log symbols
            .replace(/ +/g, ' ') // Normalize multiple spaces but preserve single spaces
            .substring(0, 50000); // Reasonable log size limit
        
        // Additional security: remove any remaining dangerous patterns
        // This prevents any script injection even in log content
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
            /<\/iframe/gi
        ];
        
        dangerousPatterns.forEach(pattern => {
            sanitized = sanitized.replace(pattern, '');
        });
        
        return sanitized;
    }
    
    setTextContent(elementId, content) {
        const element = document.getElementById(elementId);
        if (element) {
            element.textContent = String(content || '');
        }
    }
    
    isValidActivity(activity) {
        return activity &&
               typeof activity === 'object' &&
               typeof activity.message === 'string' &&
               typeof activity.time === 'string' &&
               activity.message.length > 0 &&
               activity.message.length < 500;
    }
    
    isValidAlert(alert) {
        const validTypes = ['info', 'warning', 'error', 'success'];
        return alert &&
               typeof alert === 'object' &&
               typeof alert.message === 'string' &&
               typeof alert.time === 'string' &&
               (!alert.type || validTypes.includes(alert.type)) &&
               alert.message.length > 0 &&
               alert.message.length < 500;
    }
    
    isValidSite(site) {
        return site &&
               typeof site === 'object' &&
               typeof site.domain === 'string' &&
               site.domain.length > 0 &&
               site.domain.length < 255 &&
               /^[a-zA-Z0-9.-]+$/.test(site.domain); // Basic domain validation
    }
    
    createActivityElement(activity) {
        const activityDiv = document.createElement('div');
        activityDiv.className = 'activity-item';
        
        const iconDiv = document.createElement('div');
        iconDiv.className = 'activity-icon';
        
        const icon = document.createElement('i');
        const iconClass = this.sanitizeInput(activity.icon) || 'fa-info-circle';
        icon.className = `fas ${iconClass}`;
        iconDiv.appendChild(icon);
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'activity-content';
        
        const message = document.createElement('p');
        message.textContent = this.sanitizeInput(activity.message);
        
        const time = document.createElement('span');
        time.className = 'activity-time';
        time.textContent = this.sanitizeInput(activity.time);
        
        contentDiv.appendChild(message);
        contentDiv.appendChild(time);
        
        activityDiv.appendChild(iconDiv);
        activityDiv.appendChild(contentDiv);
        
        return activityDiv;
    }
    
    createAlertElement(alert) {
        const alertType = this.sanitizeInput(alert.type) || 'info';
        
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert-item ${alertType}`;
        
        const iconDiv = document.createElement('div');
        iconDiv.className = `alert-icon ${alertType}`;
        
        const icon = document.createElement('i');
        icon.className = `fas ${this.getAlertIcon(alertType)}`;
        iconDiv.appendChild(icon);
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'alert-content';
        
        const message = document.createElement('p');
        message.textContent = this.sanitizeInput(alert.message);
        
        const time = document.createElement('span');
        time.className = 'alert-time';
        time.textContent = this.sanitizeInput(alert.time);
        
        contentDiv.appendChild(message);
        contentDiv.appendChild(time);
        
        alertDiv.appendChild(iconDiv);
        alertDiv.appendChild(contentDiv);
        
        return alertDiv;
    }
    
    createSiteElement(site) {
        const siteDiv = document.createElement('div');
        siteDiv.className = 'site-card';
        
        // Site header
        const headerDiv = document.createElement('div');
        headerDiv.className = 'site-header';
        
        const title = document.createElement('h3');
        title.textContent = this.sanitizeInput(site.domain);
        
        const statusDiv = document.createElement('div');
        statusDiv.className = 'site-status';
        
        const statusIndicator = document.createElement('span');
        const sanitizedStatus = this.sanitizeInput(site.status) || 'unknown';
        statusIndicator.className = `status-indicator ${sanitizedStatus}`;
        
        const statusText = document.createTextNode(sanitizedStatus);
        
        statusDiv.appendChild(statusIndicator);
        statusDiv.appendChild(statusText);
        
        headerDiv.appendChild(title);
        headerDiv.appendChild(statusDiv);
        
        // Site info
        const infoDiv = document.createElement('div');
        infoDiv.className = 'site-info';
        
        const wpInfo = document.createElement('p');
        wpInfo.innerHTML = '<strong>WordPress:</strong> ';
        wpInfo.appendChild(document.createTextNode(this.sanitizeInput(site.wp_version) || 'Unknown'));
        
        const sslInfo = document.createElement('p');
        sslInfo.innerHTML = '<strong>SSL:</strong> ';
        sslInfo.appendChild(document.createTextNode(this.sanitizeInput(site.ssl_status) || 'Unknown'));
        
        infoDiv.appendChild(wpInfo);
        infoDiv.appendChild(sslInfo);
        
        siteDiv.appendChild(headerDiv);
        siteDiv.appendChild(infoDiv);
        
        return siteDiv;
    }
    
    createNoSitesElement() {
        const siteDiv = document.createElement('div');
        siteDiv.className = 'site-card';
        
        const headerDiv = document.createElement('div');
        headerDiv.className = 'site-header';
        
        const title = document.createElement('h3');
        title.textContent = 'No sites found';
        
        headerDiv.appendChild(title);
        
        const infoDiv = document.createElement('div');
        infoDiv.className = 'site-info';
        
        const message = document.createElement('p');
        message.textContent = 'No WordPress sites are currently configured.';
        
        infoDiv.appendChild(message);
        
        siteDiv.appendChild(headerDiv);
        siteDiv.appendChild(infoDiv);
        
        return siteDiv;
    }
    
    createInfoElement(label, value) {
        const infoDiv = document.createElement('div');
        infoDiv.className = 'info-item';
        
        const labelElement = document.createElement('strong');
        labelElement.textContent = `${label}:`;
        
        const valueElement = document.createElement('span');
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
        
        Object.values(this.charts).forEach(chart => {
            if (chart && chart.destroy) {
                chart.destroy();
            }
        });
    }
}

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Only initialize if not already initialized
    if (!window.engineScriptDashboard) {
        window.engineScriptDashboard = new EngineScriptDashboard();
    }
});

// Handle page unload
window.addEventListener('beforeunload', () => {
    if (window.engineScriptDashboard) {
        window.engineScriptDashboard.destroy();
    }
});

// Security: Prevent frame embedding
if (window.top !== window.self) {
    window.top.location = window.self.location;
}
