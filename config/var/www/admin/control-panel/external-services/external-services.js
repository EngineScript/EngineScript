// EngineScript External Services Manager - ES6 Module
// Handles external service status monitoring with drag-drop ordering and preferences

import { DashboardUtils } from '../modules/utils.js?v=2025.11.12.16';

export class ExternalServicesManager {
  constructor(containerSelector, settingsContainerSelector) {
    this.utils = new DashboardUtils();
    this.container = document.querySelector(containerSelector);
    this.settingsContainer = document.querySelector(settingsContainerSelector);
    
    // State management with cache (5-minute TTL)
    this.serviceCache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes in milliseconds
  }

  /**
   * Initialize the external services manager
   */
  async init() {
    if (!this.container || !this.settingsContainer) {
      console.error('External services container or settings container not found');
      return;
    }

    await this.loadExternalServices();
  }

  /**
   * Main method to load and display all external services
   */
  async loadExternalServices() {
    try {
      this.container.innerHTML = "";

      // Get service definitions first (always available)
      const serviceDefinitions = this.getServiceDefinitions();
      
      // Try to fetch from API, but fall back to definitions if it fails
      const services = await this.fetchAvailableServices();
      
      // Load preferences from cookie (client-side only)
      let preferences = this.loadServicePreferences() || {};
      let serviceOrder = this.getServiceOrder();

      // Render settings panel in dedicated container
      this.renderServiceSettings(this.settingsContainer, services, serviceDefinitions, preferences);

      // Get service keys in custom order
      let orderedServiceKeys = serviceOrder.filter(key => services[key]);
      // Add any new services not in the saved order
      Object.keys(services).forEach(key => {
        if (!orderedServiceKeys.includes(key)) {
          orderedServiceKeys.push(key);
        }
      });

      // Check if any services are enabled (must be explicitly set to true)
      const enabledServices = orderedServiceKeys.filter(key => {
        return serviceDefinitions[key] && preferences[key] === true;
      });

      // If no services are enabled, show empty state
      if (enabledServices.length === 0) {
        const emptyState = document.createElement("div");
        emptyState.className = "empty-state";
        emptyState.innerHTML = `
          <div class="empty-state-icon">
            <i class="fas fa-toggle-off"></i>
          </div>
          <h3>No Services Selected</h3>
          <p>Click the "Service Settings" button above to enable external service monitoring.</p>
        `;
        this.container.appendChild(emptyState);
        return;
      }

      // Group enabled services by category
      const servicesByCategory = {};
      for (const serviceKey of orderedServiceKeys) {
        if (serviceDefinitions[serviceKey] && preferences[serviceKey] === true) {
          const serviceDef = serviceDefinitions[serviceKey];
          const category = serviceDef.category || 'Other';
          
          if (!servicesByCategory[category]) {
            servicesByCategory[category] = [];
          }
          servicesByCategory[category].push({ key: serviceKey, def: serviceDef });
        }
      }

      // Render services grouped by category
      for (const category in servicesByCategory) {
        // Create category header
        const categoryHeader = document.createElement("div");
        categoryHeader.className = "service-category-header";
        categoryHeader.innerHTML = `<h3>${category}</h3>`;
        this.container.appendChild(categoryHeader);

        // Create category container
        const categoryContainer = document.createElement("div");
        categoryContainer.className = "service-category-grid";
        categoryContainer.dataset.category = category;

        // Display all cards immediately with loading state, then fetch statuses asynchronously
        for (const { key: serviceKey, def: serviceDef } of servicesByCategory[category]) {
          // Check if this is a static service (no API or feed)
          if (!serviceDef.useFeed && !serviceDef.corsEnabled && !serviceDef.api) {
            // Display static card immediately (e.g., AWS)
            this.displayStaticServiceCard(categoryContainer, serviceKey, serviceDef);
          } else {
            // Display card immediately with loading state
            this.displayServiceCardWithLoadingState(categoryContainer, serviceKey, serviceDef);
            
            // Fire all requests immediately in parallel - browser and server handle concurrency
            // Each request is fully independent and non-blocking with its own timeout
            if (serviceDef.useFeed) {
              this.updateFeedServiceStatus(serviceKey, serviceDef).catch(err => {
                console.error(`Failed to load ${serviceDef.name}:`, err);
              });
            } else if (serviceDef.corsEnabled && serviceDef.api) {
              this.updateStatusPageServiceStatus(serviceKey, serviceDef).catch(err => {
                console.error(`Failed to load ${serviceDef.name}:`, err);
              });
            }
          }
        }

        this.container.appendChild(categoryContainer);
      }
      
      // Enable drag and drop for service cards
      this.enableServiceDragDrop(this.container);
    } catch (error) {
      console.error('Failed to load external services:', error);
      this.container.innerHTML = "";
      const errorDiv = document.createElement("div");
      errorDiv.className = "error-state";
      errorDiv.innerHTML = `
        <div class="error-icon">
          <i class="fas fa-exclamation-circle"></i>
        </div>
        <h3>Error Loading External Services</h3>
        <p>Failed to fetch external service status. Please try again later.</p>
      `;
      this.container.appendChild(errorDiv);
    }
  }

  /**
   * Fetch available services from API
   */
  async fetchAvailableServices() {
    try {
      const response = await fetch("/api/external-services/config", { credentials: 'include' });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      let services = data.services || data;
      
      // If API failed or returned empty, use all services from definitions
      if (!services || Object.keys(services).length === 0) {
        const serviceDefinitions = this.getServiceDefinitions();
        services = {};
        Object.keys(serviceDefinitions).forEach(key => {
          services[key] = true;
        });
      }
      
      return services;
    } catch (error) {
      console.error('Failed to fetch services config:', error);
      // Fallback: return all services enabled
      const serviceDefinitions = this.getServiceDefinitions();
      const services = {};
      Object.keys(serviceDefinitions).forEach(key => {
        services[key] = true;
      });
      return services;
    }
  }

  /**
   * Get service definitions for all supported external services
   */
  getServiceDefinitions() {
    return {
      // HOSTING & INFRASTRUCTURE
      aws: {
        name: 'AWS',
        category: 'Hosting & Infrastructure',
        url: 'https://health.aws.amazon.com/health/status',
        icon: 'fa-server',
        color: 'aws-icon',
        corsEnabled: false,
        statusText: 'Visit status page'
      },
      cloudflare: {
        name: 'Cloudflare',
        category: 'Hosting & Infrastructure',
        api: 'https://www.cloudflarestatus.com/api/v2/status.json',
        url: 'https://www.cloudflarestatus.com/',
        icon: 'fa-cloud',
        color: 'cloudflare-icon',
        corsEnabled: true
      },
      cloudways: {
        name: 'Cloudways',
        category: 'Hosting & Infrastructure',
        api: 'https://status.cloudways.com/api/v2/status.json',
        url: 'https://status.cloudways.com/',
        icon: 'fa-cloud-upload-alt',
        color: 'cloudways-icon',
        corsEnabled: true
      },
      digitalocean: {
        name: 'DigitalOcean',
        category: 'Hosting & Infrastructure',
        api: 'https://status.digitalocean.com/api/v2/status.json',
        url: 'https://status.digitalocean.com/',
        icon: 'fa-water',
        color: 'digitalocean-icon',
        corsEnabled: true
      },
      googlecloud: {
        name: 'Google Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'googlecloud',
        url: 'https://status.cloud.google.com/',
        icon: 'fa-google',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      hostinger: {
        name: 'Hostinger',
        category: 'Hosting & Infrastructure',
        api: 'https://statuspage.hostinger.com/api/v2/status.json',
        url: 'https://statuspage.hostinger.com/',
        icon: 'fa-h-square',
        color: 'hostinger-icon',
        corsEnabled: true
      },
      kinsta: {
        name: 'Kinsta',
        category: 'Hosting & Infrastructure',
        api: 'https://status.kinsta.com/api/v2/status.json',
        url: 'https://status.kinsta.com/',
        icon: 'fa-bolt',
        color: 'kinsta-icon',
        corsEnabled: true
      },
      linode: {
        name: 'Linode',
        category: 'Hosting & Infrastructure',
        api: 'https://status.linode.com/api/v2/status.json',
        url: 'https://status.linode.com/',
        icon: 'fa-cube',
        color: 'linode-icon',
        corsEnabled: true
      },
      oracle: {
        name: 'Oracle Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'oracle',
        url: 'https://ocistatus.oraclecloud.com/',
        icon: 'fa-database',
        color: 'oracle-icon',
        corsEnabled: false,
        useFeed: true
      },
      ovh: {
        name: 'OVH Cloud',
        category: 'Hosting & Infrastructure',
        feedType: 'ovh',
        url: 'https://public-cloud.status-ovhcloud.com/',
        icon: 'fa-cloud',
        color: 'ovh-icon',
        corsEnabled: false,
        useFeed: true
      },
      scaleway: {
        name: 'Scaleway',
        category: 'Hosting & Infrastructure',
        api: 'https://status.scaleway.com/api/v2/status.json',
        url: 'https://status.scaleway.com/',
        icon: 'fa-layer-group',
        color: 'scaleway-icon',
        corsEnabled: true
      },
      upcloud: {
        name: 'UpCloud',
        category: 'Hosting & Infrastructure',
        api: 'https://status.upcloud.com/api/v2/status.json',
        url: 'https://status.upcloud.com/',
        icon: 'fa-arrow-up',
        color: 'upcloud-icon',
        corsEnabled: true
      },
      vercel: {
        name: 'Vercel',
        category: 'Hosting & Infrastructure',
        api: 'https://www.vercel-status.com/api/v2/status.json',
        url: 'https://www.vercel-status.com/',
        icon: 'fa-triangle',
        color: 'vercel-icon',
        corsEnabled: true
      },
      vultr: {
        name: 'Vultr',
        category: 'Hosting & Infrastructure',
        feedType: 'vultr',
        url: 'https://status.vultr.com/',
        icon: 'fa-bolt',
        color: 'vultr-icon',
        corsEnabled: false,
        useFeed: true
      },
      // DEVELOPER TOOLS
      codacy: {
        name: 'Codacy',
        category: 'Developer Tools',
        feedType: 'codacy',
        url: 'https://status.codacy.com/',
        icon: 'fa-code-branch',
        color: 'codacy-icon',
        corsEnabled: false,
        useFeed: true
      },
      github: {
        name: 'GitHub',
        category: 'Developer Tools',
        api: 'https://www.githubstatus.com/api/v2/status.json',
        url: 'https://www.githubstatus.com/',
        icon: 'fa-github',
        color: 'github-icon',
        corsEnabled: true
      },
      gitlab: {
        name: 'GitLab',
        category: 'Developer Tools',
        feedType: 'gitlab',
        url: 'https://status.gitlab.com/',
        icon: 'fa-gitlab',
        color: 'gitlab-icon',
        corsEnabled: false,
        useFeed: true
      },
      notion: {
        name: 'Notion',
        category: 'Developer Tools',
        api: 'https://www.notion-status.com/api/v2/status.json',
        url: 'https://www.notion-status.com/',
        icon: 'fa-file-alt',
        color: 'notion-icon',
        corsEnabled: true
      },
      pipedream: {
        name: 'Pipedream',
        category: 'Developer Tools',
        feedType: 'pipedream',
        url: 'https://status.pipedream.com/',
        icon: 'fa-project-diagram',
        color: 'pipedream-icon',
        corsEnabled: false,
        useFeed: true
      },
      postmark: {
        name: 'Postmark',
        category: 'Email & Communication',
        feedType: 'postmark',
        url: 'https://status.postmarkapp.com/',
        icon: 'fa-paper-plane',
        color: 'postmark-icon',
        corsEnabled: false,
        useFeed: true
      },
      trello: {
        name: 'Trello',
        category: 'Developer Tools',
        feedType: 'trello',
        url: 'https://trello.status.atlassian.com/',
        icon: 'fa-trello',
        color: 'trello-icon',
        corsEnabled: false,
        useFeed: true
      },
      twilio: {
        name: 'Twilio',
        category: 'Developer Tools',
        api: 'https://status.twilio.com/api/v2/status.json',
        url: 'https://status.twilio.com/',
        icon: 'fa-sms',
        color: 'twilio-icon',
        corsEnabled: true
      },
      // PAYMENT PROCESSING
      coinbase: {
        name: 'Coinbase',
        category: 'E-Commerce & Payments',
        api: 'https://status.coinbase.com/api/v2/status.json',
        url: 'https://status.coinbase.com/',
        icon: 'fa-bitcoin',
        color: 'coinbase-icon',
        corsEnabled: true
      },
      paypal: {
        name: 'PayPal',
        category: 'E-Commerce & Payments',
        feedType: 'paypal',
        url: 'https://www.paypal-status.com/product/production',
        icon: 'fa-paypal',
        color: 'paypal-icon',
        corsEnabled: false,
        useFeed: true
      },
      recurly: {
        name: 'Recurly',
        category: 'E-Commerce & Payments',
        feedType: 'recurly',
        url: 'https://status.recurly.com/',
        icon: 'fa-repeat',
        color: 'recurly-icon',
        corsEnabled: false,
        useFeed: true
      },
      square: {
        name: 'Square',
        category: 'E-Commerce & Payments',
        feedType: 'square',
        url: 'https://www.issquareup.com/',
        icon: 'fa-square',
        color: 'square-icon',
        corsEnabled: false,
        useFeed: true
      },
      stripe: {
        name: 'Stripe',
        category: 'E-Commerce & Payments',
        feedType: 'stripe',
        url: 'https://status.stripe.com/',
        icon: 'fa-credit-card',
        color: 'stripe-icon',
        corsEnabled: false,
        useFeed: true
      },
      // EMAIL & COMMUNICATION
      discord: {
        name: 'Discord',
        category: 'Email & Communication',
        api: 'https://discordstatus.com/api/v2/status.json',
        url: 'https://discordstatus.com/',
        icon: 'fa-discord',
        color: 'discord-icon',
        corsEnabled: true
      },
      brevo: {
        name: 'Brevo',
        category: 'Email & Communication',
        feedType: 'brevo',
        url: 'https://status.brevo.com/',
        icon: 'fa-envelope-open',
        color: 'brevo-icon',
        corsEnabled: false,
        useFeed: true
      },
      mailgun: {
        name: 'Mailgun',
        category: 'Email & Communication',
        api: 'https://status.mailgun.com/api/v2/status.json',
        url: 'https://status.mailgun.com/',
        icon: 'fa-envelope',
        color: 'mailgun-icon',
        corsEnabled: true
      },
      sendgrid: {
        name: 'SendGrid',
        category: 'Email & Communication',
        feedType: 'sendgrid',
        url: 'https://status.sendgrid.com/',
        icon: 'fa-envelope',
        color: 'sendgrid-icon',
        corsEnabled: false,
        useFeed: true
      },
      slack: {
        name: 'Slack',
        category: 'Email & Communication',
        feedType: 'slack',
        url: 'https://slack-status.com/',
        icon: 'fa-slack',
        color: 'slack-icon',
        corsEnabled: false,
        useFeed: true
      },
      zoom: {
        name: 'Zoom',
        category: 'Email & Communication',
        api: 'https://www.zoomstatus.com/api/v2/status.json',
        url: 'https://www.zoomstatus.com/',
        icon: 'fa-video',
        color: 'zoom-icon',
        corsEnabled: true
      },
      // E-COMMERCE
      intuit: {
        name: 'Intuit',
        category: 'E-Commerce & Payments',
        api: 'https://status.developer.intuit.com/api/v2/status.json',
        url: 'https://status.developer.intuit.com/',
        icon: 'fa-calculator',
        color: 'intuit-icon',
        corsEnabled: true
      },
      shopify: {
        name: 'Shopify',
        category: 'E-Commerce & Payments',
        api: 'https://www.shopifystatus.com/api/v2/status.json',
        url: 'https://www.shopifystatus.com/',
        icon: 'fa-shopping-bag',
        color: 'shopify-icon',
        corsEnabled: true
      },
      // MEDIA & CONTENT
      woocommercepay: {
        name: 'WooCommerce Pay API',
        category: 'E-Commerce & Payments',
        feedType: 'automattic',
        feedFilter: 'WooCommerce Pay API',
        url: 'https://automatticstatus.com/',
        icon: 'fa-shopping-cart',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      wpcloudapi: {
        name: 'WP Cloud API',
        category: 'Hosting & Infrastructure',
        feedType: 'automattic',
        feedFilter: 'WP Cloud API',
        url: 'https://automatticstatus.com/',
        icon: 'fa-cloud',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      mailpoet: {
        name: 'MailPoet',
        category: 'Email & Communication',
        feedType: 'automattic',
        feedFilter: 'MailPoet Sending Service',
        url: 'https://automatticstatus.com/',
        icon: 'fa-envelope',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      jetpackapi: {
        name: 'Jetpack API',
        category: 'Hosting & Infrastructure',
        feedType: 'automattic',
        feedFilter: 'Jetpack API',
        url: 'https://automatticstatus.com/',
        icon: 'fa-rocket',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      wordpressapi: {
        name: 'WordPress.com API',
        category: 'Hosting & Infrastructure',
        feedType: 'automattic',
        feedFilter: 'WordPress.com API',
        url: 'https://automatticstatus.com/',
        icon: 'fa-wordpress',
        color: 'wordpress-icon',
        corsEnabled: false,
        useFeed: true
      },
      dropbox: {
        name: 'Dropbox',
        category: 'Media & Content',
        api: 'https://status.dropbox.com/api/v2/status.json',
        url: 'https://status.dropbox.com/',
        icon: 'fa-dropbox',
        color: 'dropbox-icon',
        corsEnabled: true
      },
      reddit: {
        name: 'Reddit',
        category: 'Media & Content',
        api: 'https://www.redditstatus.com/api/v2/status.json',
        url: 'https://www.redditstatus.com/',
        icon: 'fa-reddit',
        color: 'reddit-icon',
        corsEnabled: true
      },
      udemy: {
        name: 'Udemy',
        category: 'Media & Content',
        api: 'https://status.udemy.com/api/v2/status.json',
        url: 'https://status.udemy.com/',
        icon: 'fa-graduation-cap',
        color: 'udemy-icon',
        corsEnabled: true
      },
      vimeo: {
        name: 'Vimeo',
        category: 'Media & Content',
        api: 'https://www.vimeostatus.com/api/v2/status.json',
        url: 'https://status.vimeo.com/',
        icon: 'fa-vimeo',
        color: 'vimeo-icon',
        corsEnabled: true
      },
      wistia: {
        name: 'Wistia',
        category: 'Media & Content',
        feedType: 'wistia',
        url: 'https://status.wistia.com/',
        icon: 'fa-play-circle',
        color: 'wistia-icon',
        corsEnabled: false,
        useFeed: true
      },
      spotify: {
        name: 'Spotify',
        category: 'Media & Content',
        feedType: 'spotify',
        url: 'https://spotify.statuspage.io/',
        icon: 'fa-spotify',
        color: 'spotify-icon',
        corsEnabled: false,
        useFeed: true
      },
      // AI & MACHINE LEARNING
      openai: {
        name: 'OpenAI',
        category: 'AI & Machine Learning',
        feedType: 'openai',
        url: 'https://status.openai.com/',
        icon: 'fa-brain',
        color: 'openai-icon',
        corsEnabled: false,
        useFeed: true
      },
      anthropic: {
        name: 'Anthropic (Claude)',
        category: 'AI & Machine Learning',
        feedType: 'anthropic',
        url: 'https://status.claude.com/',
        icon: 'fa-robot',
        color: 'anthropic-icon',
        corsEnabled: false,
        useFeed: true
      },
      // ADVERTISING
      googleads: {
        name: 'Google Ads',
        category: 'Advertising',
        feedType: 'googleads',
        url: 'https://ads.google.com/status/publisher/',
        icon: 'fa-ad',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      microsoftads: {
        name: 'Microsoft Advertising',
        category: 'Advertising',
        feedType: 'microsoftads',
        url: 'https://status.ads.microsoft.com/',
        icon: 'fa-microsoft',
        color: 'microsoft-icon',
        corsEnabled: false,
        useFeed: true
      },
      metafb: {
        name: 'Meta: Facebook & Instagram Shops',
        category: 'E-Commerce & Payments',
        feedType: 'metafb',
        url: 'https://metastatus.com/',
        icon: 'fa-facebook',
        color: 'facebook-icon',
        corsEnabled: false,
        useFeed: true
      },
      metamarketingapi: {
        name: 'Meta: Marketing API',
        category: 'Advertising',
        feedType: 'metamarketingapi',
        url: 'https://metastatus.com/',
        icon: 'fa-facebook',
        color: 'facebook-icon',
        corsEnabled: false,
        useFeed: true
      },
      metafbs: {
        name: 'Meta: Business Suite',
        category: 'Advertising',
        feedType: 'metafbs',
        url: 'https://metastatus.com/',
        icon: 'fa-facebook',
        color: 'facebook-icon',
        corsEnabled: false,
        useFeed: true
      },
      metalogin: {
        name: 'Meta: Facebook Login',
        category: 'Developer Tools',
        feedType: 'metalogin',
        url: 'https://metastatus.com/',
        icon: 'fa-facebook',
        color: 'facebook-icon',
        corsEnabled: false,
        useFeed: true
      },
      googleworkspace: {
        name: 'Google Workspace',
        category: 'Developer Tools',
        feedType: 'googleworkspace',
        url: 'https://www.google.com/appsstatus/dashboard/',
        icon: 'fa-google',
        color: 'google-icon',
        corsEnabled: false,
        useFeed: true
      },
      // SECURITY
      letsencrypt: {
        name: "Let's Encrypt",
        category: 'Security',
        feedType: 'letsencrypt',
        url: 'https://letsencrypt.status.io/',
        icon: 'fa-lock',
        color: 'letsencrypt-icon',
        corsEnabled: false,
        useFeed: true
      },
      flare: {
        name: 'Flare',
        category: 'Security',
        feedType: 'flare',
        url: 'https://status.flare.io/',
        icon: 'fa-shield-alt',
        color: 'flare-icon',
        corsEnabled: false,
        useFeed: true
      }
    };
  }

  /**
   * Render the service settings panel with toggles
   */
  renderServiceSettings(settingsContainer, services, serviceDefinitions, preferences) {
    settingsContainer.innerHTML = "";
    
    const settingsToggle = document.createElement("button");
    settingsToggle.className = "settings-toggle-btn";
    settingsToggle.innerHTML = `
      <i class="fas fa-cog"></i>
      <span>Service Settings</span>
      <i class="fas fa-chevron-down toggle-icon"></i>
    `;
    
    const settingsContent = document.createElement("div");
    settingsContent.className = "settings-content collapsed";
    
    const settingsHeader = document.createElement("div");
    settingsHeader.className = "settings-header";
    settingsHeader.innerHTML = `<p>Toggle services to show/hide on the dashboard. Drag service cards to reorder them. Click "Save Changes" to apply. Services are organized by category.</p>`;
    
    settingsContent.appendChild(settingsHeader);
    
    // Track pending changes
    const pendingChanges = {};
    
    settingsToggle.addEventListener("click", () => {
      const isCollapsed = settingsContent.classList.toggle("collapsed");
      const icon = settingsToggle.querySelector(".toggle-icon");
      icon.className = isCollapsed ? "fas fa-chevron-down toggle-icon" : "fas fa-chevron-up toggle-icon";
    });
    
    settingsContainer.appendChild(settingsToggle);
    settingsContainer.appendChild(settingsContent);

    // Group services by category
    const categories = {};
    for (const [serviceKey] of Object.entries(services)) {
      if (serviceDefinitions[serviceKey]) {
        const category = serviceDefinitions[serviceKey].category || 'Other';
        if (!categories[category]) {
          categories[category] = [];
        }
        categories[category].push(serviceKey);
      }
    }

    // Render each category
    const categoryOrder = [
      'Hosting & Infrastructure',
      'Developer Tools',
      'E-Commerce & Payments',
      'Email & Communication',
      'Media & Content',
      'Gaming',
      'AI & Machine Learning',
      'Advertising',
      'Security',
      'Other'
    ];

    categoryOrder.forEach(categoryName => {
      if (categories[categoryName]) {
        const categorySection = document.createElement("div");
        categorySection.className = "settings-category";
        
        const categoryTitle = document.createElement("h4");
        categoryTitle.className = "category-title";
        categoryTitle.textContent = categoryName;
        categorySection.appendChild(categoryTitle);
        
        const categoryGrid = document.createElement("div");
        categoryGrid.className = "settings-grid";
        
        // Sort services alphabetically within category
        categories[categoryName].sort((a, b) => {
          return serviceDefinitions[a].name.localeCompare(serviceDefinitions[b].name);
        });
        
        categories[categoryName].forEach(serviceKey => {
          const isEnabled = preferences[serviceKey] === true;
          
          const toggleLabel = document.createElement("label");
          toggleLabel.className = "service-toggle";
          const checkbox = document.createElement("input");
          checkbox.type = "checkbox";
          checkbox.checked = isEnabled;
          checkbox.dataset.service = serviceKey;
          checkbox.addEventListener("change", () => {
            pendingChanges[serviceKey] = checkbox.checked;
            saveButton.disabled = false;
            saveButton.classList.add('has-changes');
          });
          
          const serviceName = document.createElement("span");
          serviceName.textContent = serviceDefinitions[serviceKey].name;
          
          toggleLabel.appendChild(checkbox);
          toggleLabel.appendChild(serviceName);
          categoryGrid.appendChild(toggleLabel);
        });
        
        categorySection.appendChild(categoryGrid);
        settingsContent.appendChild(categorySection);
      }
    });
    
    // Add save button
    const saveButton = document.createElement("button");
    saveButton.className = "settings-save-btn";
    saveButton.disabled = true;
    saveButton.innerHTML = `<i class="fas fa-save"></i> Save Changes`;
    saveButton.addEventListener("click", async () => {
      if (Object.keys(pendingChanges).length > 0) {
        await this.saveServicePreferences(pendingChanges);
        Object.keys(pendingChanges).forEach(key => delete pendingChanges[key]);
        saveButton.disabled = true;
        saveButton.classList.remove('has-changes');
        
        // Collapse the settings panel
        settingsContent.classList.add('collapsed');
        const toggleIcon = settingsToggle.querySelector('.toggle-icon');
        if (toggleIcon) {
          toggleIcon.className = 'fas fa-chevron-down toggle-icon';
        }
      }
    });
    
    settingsContent.appendChild(saveButton);
  }

  /**
   * Enable drag-and-drop reordering for service cards
   */
  enableServiceDragDrop(container) {
    const categoryGrids = container.querySelectorAll('.service-category-grid');
    
    categoryGrids.forEach(grid => {
      const cards = grid.querySelectorAll('.external-service-card');
      let draggedElement = null;
      let dropTargetElement = null;
      
      cards.forEach(card => {
        card.draggable = true;
        
        card.addEventListener('dragstart', (e) => {
          draggedElement = card;
          card.classList.add('dragging');
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('text/html', card.innerHTML);
        });
        
        card.addEventListener('dragend', () => {
          card.classList.remove('dragging');
          
          // Remove drag-over class from all cards
          cards.forEach(c => c.classList.remove('drag-over'));
          
          // Perform swap if there's a valid drop target
          if (dropTargetElement && dropTargetElement !== draggedElement && grid.contains(dropTargetElement)) {
            // Get parent references before swapping
            const draggedParent = draggedElement.parentNode;
            const targetParent = dropTargetElement.parentNode;
            
            // Only swap if both are in the same grid
            if (draggedParent === targetParent) {
              // Get next siblings to preserve position
              const draggedNext = draggedElement.nextSibling;
              const targetNext = dropTargetElement.nextSibling;
              
              // Swap positions
              if (draggedNext === dropTargetElement) {
                // Adjacent: dragged is before target
                draggedParent.insertBefore(dropTargetElement, draggedElement);
              } else if (targetNext === draggedElement) {
                // Adjacent: target is before dragged
                draggedParent.insertBefore(draggedElement, dropTargetElement);
              } else {
                // Not adjacent: swap positions
                draggedParent.insertBefore(draggedElement, targetNext);
                targetParent.insertBefore(dropTargetElement, draggedNext);
              }
            }
          }
          
          // Reset drop target
          dropTargetElement = null;
          
          // Save new order for all cards across all categories
          const allCards = container.querySelectorAll('.external-service-card');
          const newOrder = Array.from(allCards).map(child => child.dataset.serviceKey);
          this.saveServiceOrder(newOrder);
        });
        
        card.addEventListener('dragover', (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'move';
        });
        
        card.addEventListener('dragenter', (e) => {
          // Find the card element even if hovering over child
          let targetCard = e.target;
          while (targetCard && !targetCard.classList.contains('external-service-card')) {
            targetCard = targetCard.parentElement;
          }
          
          if (targetCard && targetCard !== draggedElement && grid.contains(targetCard)) {
            // Remove drag-over from previous target
            if (dropTargetElement && dropTargetElement !== targetCard) {
              dropTargetElement.classList.remove('drag-over');
            }
            
            // Set new drop target and add visual indicator
            dropTargetElement = targetCard;
            targetCard.classList.add('drag-over');
          }
        });
        
        card.addEventListener('dragleave', (e) => {
          // Find the card element
          let targetCard = e.target;
          while (targetCard && !targetCard.classList.contains('external-service-card')) {
            targetCard = targetCard.parentElement;
          }
          
          if (targetCard) {
            // Only remove if we're actually leaving the card
            const rect = targetCard.getBoundingClientRect();
            if (e.clientX < rect.left || e.clientX > rect.right || 
                e.clientY < rect.top || e.clientY > rect.bottom) {
              targetCard.classList.remove('drag-over');
              // Clear drop target if leaving
              if (dropTargetElement === targetCard) {
                dropTargetElement = null;
              }
            }
          }
        });
      });
    });
  }

  /**
   * Save service preferences to cookie (client-side storage)
   */
  async saveServicePreferences(changes) {
    try {
      // Get all service definitions to validate
      const serviceDefinitions = this.getServiceDefinitions();
      
      // Get current preferences from cookie
      let preferences = {};
      const cookiePrefs = this.getCookie('servicePreferences');
      if (cookiePrefs) {
        try {
          preferences = JSON.parse(decodeURIComponent(cookiePrefs));
        } catch (e) {
          console.error('Failed to parse cookie preferences:', e);
          preferences = {};
        }
      }
      
      // Update all pending preferences
      Object.keys(changes).forEach(serviceKey => {
        if (serviceDefinitions[serviceKey]) {
          preferences[serviceKey] = Boolean(changes[serviceKey]);
        }
      });
      
      // Save to cookie (1 year expiration)
      this.setCookie('servicePreferences', encodeURIComponent(JSON.stringify(preferences)), 365);
      
      // Clear cache on preferences change
      this.serviceCache.clear();
      
      // Reload services
      await this.loadExternalServices();
      
      this.showNotification("Preferences saved successfully", "success");
    } catch (error) {
      console.error('Failed to save service preferences:', error);
      this.showNotification("Failed to save preferences", "error");
    }
  }

  /**
   * Display static service card (no API/feed)
   */
  displayStaticServiceCard(container, serviceKey, serviceDef) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = "external-service-card static";
    serviceLink.dataset.serviceKey = serviceKey;
    
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    iconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h3 = document.createElement("h3");
    h3.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = "service-status status-info";
    statusSpan.innerHTML = `<i class="fas fa-external-link-alt"></i> `;
    statusSpan.appendChild(document.createTextNode(serviceDef.statusText || 'Visit status page'));
    
    infoDiv.appendChild(h3);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    serviceLink.appendChild(headerDiv);
    
    container.appendChild(serviceLink);
  }

  /**
   * Display service card with loading state
   */
  displayServiceCardWithLoadingState(container, serviceKey, serviceDef) {
    const serviceLink = document.createElement("a");
    serviceLink.href = serviceDef.url;
    serviceLink.target = "_blank";
    serviceLink.rel = "noopener noreferrer";
    serviceLink.className = "external-service-card loading";
    serviceLink.dataset.serviceKey = serviceKey;
    
    const headerDiv = document.createElement("div");
    headerDiv.className = "service-header";
    
    const iconDiv = document.createElement("div");
    iconDiv.className = `service-icon ${serviceDef.color}`;
    iconDiv.innerHTML = `<i class="fas ${serviceDef.icon}"></i>`;
    
    const infoDiv = document.createElement("div");
    infoDiv.className = "service-info";
    
    const h3 = document.createElement("h3");
    h3.textContent = serviceDef.name;
    
    const statusSpan = document.createElement("span");
    statusSpan.className = "service-status status-loading";
    statusSpan.innerHTML = `<i class="fas fa-spinner fa-spin"></i> `;
    statusSpan.appendChild(document.createTextNode("Loading..."));
    
    infoDiv.appendChild(h3);
    infoDiv.appendChild(statusSpan);
    headerDiv.appendChild(iconDiv);
    headerDiv.appendChild(infoDiv);
    serviceLink.appendChild(headerDiv);
    
    container.appendChild(serviceLink);
  }

  /**
   * Update feed-based service status asynchronously
   */
  async updateFeedServiceStatus(serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        let apiUrl = `/api/external-services/feed?feed=${encodeURIComponent(serviceDef.feedType)}`;
        if (serviceDef.feedFilter) {
          apiUrl += `&filter=${encodeURIComponent(serviceDef.feedFilter)}`;
        }
        
        const response = await fetch(apiUrl, {
          signal: controller.signal,
          credentials: 'include'
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status) {
        throw new Error('Invalid feed response format');
      }

      // Find the card and update it
      const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
      if (!serviceCard) {
        console.error(`Card not found for service: ${serviceKey}`);
        return;
      }
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";
      
      // Update card class
      serviceCard.classList.remove("loading", "error");
      
      // Update status span
      const statusSpan = serviceCard.querySelector(".service-status");
      if (statusSpan) {
        statusSpan.className = `service-status status-${statusColor}`;
        statusSpan.innerHTML = `<i class="fas fa-${statusIcon}"></i> `;
        statusSpan.appendChild(document.createTextNode(this.utils.sanitizeInput(data.status.description)));
      }
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} feed status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Update StatusPage.io service status asynchronously
   */
  async updateStatusPageServiceStatus(serviceKey, serviceDef) {
    try {
      // Check cache first
      let data = this.getCachedService(serviceKey);
      
      if (!data) {
        // Not in cache, fetch from API
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        const response = await fetch(serviceDef.api, {
          signal: controller.signal
        });
        clearTimeout(timeoutId);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        data = await response.json();
        
        // Cache the response
        this.setCachedService(serviceKey, data);
      }
      
      if (!data || !data.status || !data.status.indicator) {
        throw new Error('Invalid API response format');
      }

      // Find the card and update it
      const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
      if (!serviceCard) {
        console.error(`Card not found for service: ${serviceKey}`);
        return;
      }
      
      const statusClass = data.status.indicator === "none" ? "operational" : data.status.indicator;
      const statusIcon = statusClass === "operational" ? "check-circle" : "exclamation-triangle";
      const statusColor = statusClass === "operational" ? "success" : statusClass === "minor" ? "warning" : "error";
      
      // Update card class
      serviceCard.classList.remove("loading", "error");
      
      // Update status span
      const statusSpan = serviceCard.querySelector(".service-status");
      if (statusSpan) {
        statusSpan.className = `service-status status-${statusColor}`;
        statusSpan.innerHTML = `<i class="fas fa-${statusIcon}"></i> `;
        statusSpan.appendChild(document.createTextNode(this.utils.sanitizeInput(data.status.description)));
      }
    } catch (error) {
      console.error(`Failed to load ${serviceDef.name} status:`, error);
      this.handleServiceError(serviceKey, serviceDef, error);
    }
  }

  /**
   * Handle service loading errors
   */
  handleServiceError(serviceKey, serviceDef, error) {
    let errorMessage = 'Unable to fetch status';
    if (error.name === 'AbortError') {
      errorMessage = 'Request timed out';
    } else if (error.message && error.message.startsWith('HTTP error!')) {
      errorMessage = 'Service unavailable';
    }
    
    // Find the card and update it with error state
    const serviceCard = document.querySelector(`[data-service-key="${serviceKey}"]`);
    if (!serviceCard) {
      console.error(`Card not found for service: ${serviceKey}`);
      return;
    }
    
    serviceCard.classList.remove("loading");
    serviceCard.classList.add("error");
    
    const statusSpan = serviceCard.querySelector(".service-status");
    if (statusSpan) {
      statusSpan.className = "service-status status-error";
      statusSpan.innerHTML = `<i class="fas fa-times-circle"></i> `;
      statusSpan.appendChild(document.createTextNode(errorMessage));
    }
  }

  // ============ Cache Management ============

  /**
   * Get cached service data
   */
  getCachedService(serviceKey) {
    const cached = this.serviceCache.get(serviceKey);
    if (!cached) return null;
    
    const now = Date.now();
    if (now - cached.timestamp > this.cacheTTL) {
      this.serviceCache.delete(serviceKey);
      return null;
    }
    
    return cached.data;
  }

  /**
   * Set cached service data
   */
  setCachedService(serviceKey, data) {
    this.serviceCache.set(serviceKey, {
      data: data,
      timestamp: Date.now()
    });
  }

  /**
   * Clear service cache
   */
  clearCache() {
    this.serviceCache.clear();
  }

  // ============ Cookie Management ============

  /**
   * Get cookie value
   */
  getCookie(name) {
    const nameEQ = name + "=";
    const ca = document.cookie.split(';');
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i];
      while (c.charAt(0) === ' ') c = c.substring(1, c.length);
      if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
  }

  /**
   * Set cookie value
   */
  setCookie(name, value, days = 365) {
    let expires = "";
    if (days) {
      const date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    // Set cookie with SameSite=Lax for security
    document.cookie = name + "=" + (value || "") + expires + "; path=/; SameSite=Lax";
  }

  /**
   * Delete cookie
   */
  deleteCookie(name) {
    document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  }

  // ============ Service Preferences ============

  /**
   * Load service preferences from cookie
   */
  loadServicePreferences() {
    try {
      // Try to load from cookie first
      const cookiePrefs = this.getCookie('servicePreferences');
      if (cookiePrefs) {
        try {
          const parsed = JSON.parse(decodeURIComponent(cookiePrefs));
          // Validate it's an object with expected structure
          if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
            return parsed;
          }
        } catch (parseError) {
          console.error('Failed to parse cookie preferences:', parseError);
          // Clear invalid cookie
          this.deleteCookie('servicePreferences');
        }
      }
      
      // Return null if no valid preferences found - will use defaults
      return null;
    } catch (error) {
      console.error('Failed to load service preferences:', error);
      return null;
    }
  }

  /**
   * Get service order from cookie
   */
  getServiceOrder() {
    const orderCookie = this.getCookie('serviceOrder');
    if (orderCookie) {
      try {
        return JSON.parse(decodeURIComponent(orderCookie));
      } catch (e) {
        console.error('Failed to parse service order:', e);
      }
    }
    // Default alphabetical order by category
    return [
      // Hosting & Infrastructure
      'aws', 'cloudflare', 'cloudways', 'digitalocean', 'googlecloud', 'hostinger', 'jetpackapi', 'kinsta', 
      'linode', 'oracle', 'ovh', 'scaleway', 'upcloud', 'vercel', 'vultr', 'wordpressapi', 'wpcloudapi',
      // Developer Tools
      'codacy', 'github', 'gitlab', 'googleworkspace', 'metalogin', 'notion', 'pipedream', 'postmark', 'trello', 'twilio',
      // E-Commerce & Payments
      'coinbase', 'intuit', 'metafb', 'paypal', 'recurly', 'shopify', 'square', 'stripe', 'woocommercepay',
      // Email & Communication
      'brevo', 'discord', 'mailgun', 'mailpoet', 'postmark', 'sendgrid', 'slack', 'zoom',
      // Media & Content
      'dropbox', 'reddit', 'spotify', 'udemy', 'vimeo', 'wistia',
      // Gaming
      'epicgames',
      // AI & Machine Learning
      'anthropic', 'openai',
      // Advertising
      'googleads', 'googlesearch', 'metafbs', 'metamarketingapi', 'microsoftads',
      // Security
      'flare', 'letsencrypt'
    ];
  }

  /**
   * Save service order to cookie
   */
  saveServiceOrder(orderArray) {
    this.setCookie('serviceOrder', encodeURIComponent(JSON.stringify(orderArray)), 365);
  }

  // ============ Notifications ============

  /**
   * Show notification to user
   */
  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 15px 20px;
      background: ${type === 'success' ? '#00d4aa' : type === 'error' ? '#f44' : '#00a8ff'};
      color: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      z-index: 10000;
      animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }
}
