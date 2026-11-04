// EngineScript Admin Dashboard - State Management Module
// Manages application state and configuration

export class DashboardState {
  constructor() {
    this.currentPage = "overview";
    this.refreshInterval = 300000; // 5 minutes
    this.refreshTimer = null;
    this.allowedPages = ["overview", "sites", "system", "tools"];
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

  isValidPage(page) {
    return this.allowedPages.includes(page);
  }

  getPageTitle(pageName) {
    const titles = {
      overview: "Overview",
      sites: "WordPress Sites",
      system: "System Information",
      tools: "Admin Tools"
    };
    return titles[pageName] || "Dashboard";
  }
}
