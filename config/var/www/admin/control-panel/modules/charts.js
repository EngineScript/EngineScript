// EngineScript Admin Dashboard - Charts Module
// DEPRECATED - Chart.js removed from project
// This module is no longer imported or used
// Kept for reference only - safe to delete

/**
 * @deprecated No longer used - Chart.js dependency removed
 */
export class DashboardCharts {
  constructor() {
    console.warn('DashboardCharts is deprecated and no longer used');
    this.charts = {};
  }

  destroy() {
    Object.values(this.charts).forEach((chart) => {
      if (chart && chart.destroy) {
        chart.destroy();
      }
    });
    this.charts = {};
  }
}
