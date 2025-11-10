// EngineScript Admin Dashboard - Charts Module
// Handles Chart.js initialization and management

/* global Chart */

export class DashboardCharts {
  constructor() {
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
