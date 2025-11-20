// EngineScript Admin Dashboard - Theme Management Module
// Manages light/dark theme switching with localStorage persistence

export class ThemeManager {
  constructor() {
    this.currentTheme = 'dark'; // default theme
    this.storageKey = 'enginescript-theme';
    this.themeToggleButton = null;
    
    // Load saved theme before DOM renders (prevent flash)
    this.loadSavedTheme();
  }

  /**
   * Initialize theme manager
   * Sets up theme toggle button and event listeners
   */
  init() {
    this.createThemeToggle();
    this.attachEventListeners();
    console.log('[Theme] Theme manager initialized. Current theme:', this.currentTheme);
  }

  /**
   * Load saved theme from localStorage
   * Called immediately to prevent theme flash on page load
   */
  loadSavedTheme() {
    try {
      const savedTheme = localStorage.getItem(this.storageKey);
      if (savedTheme === 'light' || savedTheme === 'dark') {
        this.currentTheme = savedTheme;
        this.applyTheme(savedTheme, false); // Apply without animation on load
        console.log('[Theme] Loaded saved theme from localStorage:', savedTheme);
      } else {
        console.log('[Theme] No saved theme found, using default:', this.currentTheme);
      }
    } catch (error) {
      console.error('[Theme] Failed to load saved theme:', error);
    }
  }

  /**
   * Save current theme to localStorage
   */
  saveTheme() {
    try {
      localStorage.setItem(this.storageKey, this.currentTheme);
      console.log('[Theme] Theme saved to localStorage:', this.currentTheme);
    } catch (error) {
      console.error('[Theme] Failed to save theme:', error);
    }
  }

  /**
   * Apply theme to document
   * @param {string} theme - Theme name ('light' or 'dark')
   * @param {boolean} animate - Whether to animate the transition
   */
  applyTheme(theme, animate = true) {
    const root = document.documentElement;
    
    if (animate) {
      // Add transition class for smooth animation
      root.classList.add('theme-transitioning');
    }
    
    // Set data-theme attribute for CSS
    root.setAttribute('data-theme', theme);
    
    // Update Chart.js colors if charts exist
    this.updateChartColors(theme);
    
    // Remove transition class after animation completes
    if (animate) {
      setTimeout(() => {
        root.classList.remove('theme-transitioning');
      }, 300);
    }
  }

  /**
   * Toggle between light and dark themes
   */
  toggleTheme() {
    this.currentTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
    this.applyTheme(this.currentTheme, true);
    this.saveTheme();
    this.updateToggleButton();
    
    console.log('[Theme] Theme toggled to:', this.currentTheme);
  }

  /**
   * Get current theme
   * @returns {string} Current theme name
   */
  getCurrentTheme() {
    return this.currentTheme;
  }

  /**
   * Create theme toggle button in header
   */
  createThemeToggle() {
    const headerRight = document.querySelector('.header-right');
    if (!headerRight) {
      console.error('[Theme] Could not find .header-right element');
      return;
    }

    // Create container for button and label
    const container = document.createElement('div');
    container.className = 'theme-toggle-container';
    
    // Create label
    const label = document.createElement('span');
    label.className = 'theme-toggle-label';
    label.textContent = 'Theme';
    
    // Create button
    const button = document.createElement('button');
    button.id = 'theme-toggle';
    button.className = 'btn btn-secondary theme-toggle';
    button.setAttribute('aria-label', 'Toggle theme');
    button.setAttribute('title', 'Toggle light/dark theme');
    
    // Create icon
    const icon = document.createElement('i');
    icon.className = this.currentTheme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    
    button.appendChild(icon);
    container.appendChild(label);
    container.appendChild(button);
    
    // Insert before refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    if (refreshBtn) {
      headerRight.insertBefore(container, refreshBtn);
    } else {
      headerRight.insertBefore(container, headerRight.firstChild);
    }
    
    this.themeToggleButton = button;
    console.log('[Theme] Theme toggle button created');
  }

  /**
   * Update theme toggle button icon
   */
  updateToggleButton() {
    if (!this.themeToggleButton) return;
    
    const icon = this.themeToggleButton.querySelector('i');
    if (icon) {
      // Sun icon for dark mode (click to go light)
      // Moon icon for light mode (click to go dark)
      icon.className = this.currentTheme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    }
  }

  /**
   * Attach event listeners
   */
  attachEventListeners() {
    if (this.themeToggleButton) {
      this.themeToggleButton.addEventListener('click', () => this.toggleTheme());
    }
  }

  /**
   * Update Chart.js colors when theme changes
   * @param {string} theme - Current theme
   */
  updateChartColors(theme) {
    // Check if Chart.js is loaded
    if (typeof Chart === 'undefined') return;
    
    const isDark = theme === 'dark';
    
    // Update default colors for new charts
    Chart.defaults.color = isDark ? '#b3b3b3' : '#4a5568';
    Chart.defaults.borderColor = isDark ? '#444' : '#e2e8f0';
    
    // Update existing charts
    if (window.engineScriptDashboard && window.engineScriptDashboard.charts) {
      const chartsModule = window.engineScriptDashboard.charts;
      
      // Update each chart's colors
      Object.values(chartsModule.charts || {}).forEach(chart => {
        if (chart && chart.options) {
          // Update scales
          if (chart.options.scales) {
            Object.values(chart.options.scales).forEach(scale => {
              if (scale.ticks) {
                scale.ticks.color = isDark ? '#b3b3b3' : '#4a5568';
              }
              if (scale.grid) {
                scale.grid.color = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)';
              }
            });
          }
          
          // Update legend
          if (chart.options.plugins && chart.options.plugins.legend && chart.options.plugins.legend.labels) {
            chart.options.plugins.legend.labels.color = isDark ? '#b3b3b3' : '#4a5568';
          }
          
          // Update chart
          chart.update('none'); // 'none' prevents animation
        }
      });
    }
  }

  /**
   * Cleanup method
   */
  destroy() {
    if (this.themeToggleButton) {
      this.themeToggleButton.remove();
    }
  }
}
