// EngineScript Admin Dashboard - State Management Module
// Manages application state and configuration

export class DashboardState {
  constructor() {
    this.currentPage = "overview";
    this.refreshInterval = 30000; // 30 seconds
    this.refreshTimer = null;

    // Security configurations
    this.maxRefreshInterval = 300000; // 5 minutes max
    this.minRefreshInterval = 5000; // 5 seconds min
    this.allowedTimeRanges = ["1h", "6h", "24h", "48h"];
    this.allowedPages = ["overview", "sites", "system", "tools"];
    this.allowedTools = ["phpmyadmin", "phpinfo", "phpsysinfo", "adminer"];
  }

  setCurrentPage(page) {
    if (this.allowedPages.includes(page)) {
      this.currentPage = page;
      return true;
    }
    return false;
  }

  getCurrentPage() {
    return this.currentPage;
  }

  setRefreshTimer(timer) {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = timer;
  }

  clearRefreshTimer() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  isValidTimeRange(timeRange) {
    return this.allowedTimeRanges.includes(timeRange);
  }

  isValidPage(page) {
    return this.allowedPages.includes(page);
  }

  isValidTool(tool) {
    return this.allowedTools.includes(tool);
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
}
