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
}
