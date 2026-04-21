/**
 * External Services Configuration
 * Service definitions for all supported external service providers
 */

export const SERVICE_DEFINITIONS = {
  // HOSTING & INFRASTRUCTURE
  aws: {
    name: 'AWS',
    category: 'Hosting & Infrastructure',
    url: 'https://health.aws.amazon.com/health/status',
    icon: 'fa-server',
    color: 'aws-icon',
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
    useFeed: true
  },
  ovh: {
    name: 'OVH Cloud',
    category: 'Hosting & Infrastructure',
    feedType: 'ovh',
    url: 'https://public-cloud.status-ovhcloud.com/',
    icon: 'fa-cloud',
    color: 'ovh-icon',
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
    useFeed: true
  },
  godaddy: {
    name: 'GoDaddy',
    category: 'Hosting & Infrastructure',
    api: 'https://status.godaddy.com/api/v2/status.json',
    url: 'https://status.godaddy.com/',
    icon: 'fa-globe',
    color: 'godaddy-icon',
    corsEnabled: true
  },
  // DEVELOPER TOOLS
  codacy: {
    name: 'Codacy',
    category: 'Developer Tools',
    feedType: 'codacy',
    url: 'https://status.codacy.com/',
    icon: 'fa-code-branch',
    color: 'codacy-icon',
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
    useFeed: true
  },
  trello: {
    name: 'Trello',
    category: 'Developer Tools',
    feedType: 'trello',
    url: 'https://trello.status.atlassian.com/',
    icon: 'fa-trello',
    color: 'trello-icon',
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
  metalogin: {
    name: 'Meta: Facebook Login',
    category: 'Developer Tools',
    feedType: 'metalogin',
    url: 'https://metastatus.com/',
    icon: 'fa-facebook',
    color: 'facebook-icon',
    useFeed: true
  },
  googleworkspace: {
    name: 'Google Workspace',
    category: 'Developer Tools',
    feedType: 'googleworkspace',
    url: 'https://www.google.com/appsstatus/dashboard/',
    icon: 'fa-google',
    color: 'google-icon',
    useFeed: true
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
    useFeed: true
  },
  recurly: {
    name: 'Recurly',
    category: 'E-Commerce & Payments',
    feedType: 'recurly',
    url: 'https://status.recurly.com/',
    icon: 'fa-repeat',
    color: 'recurly-icon',
    useFeed: true
  },
  square: {
    name: 'Square',
    category: 'E-Commerce & Payments',
    feedType: 'square',
    url: 'https://www.issquareup.com/',
    icon: 'fa-square',
    color: 'square-icon',
    useFeed: true
  },
  stripe: {
    name: 'Stripe',
    category: 'E-Commerce & Payments',
    feedType: 'stripe',
    url: 'https://status.stripe.com/',
    icon: 'fa-credit-card',
    color: 'stripe-icon',
    useFeed: true
  },
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
  woocommercepay: {
    name: 'WooCommerce Pay API',
    category: 'E-Commerce & Payments',
    feedType: 'automattic',
    feedFilter: 'WooCommerce Pay API',
    url: 'https://automatticstatus.com/',
    icon: 'fa-shopping-cart',
    color: 'wordpress-icon',
    useFeed: true
  },
  metafb: {
    name: 'Meta: Facebook & Instagram Shops',
    category: 'E-Commerce & Payments',
    feedType: 'metafb',
    url: 'https://metastatus.com/',
    icon: 'fa-facebook',
    color: 'facebook-icon',
    useFeed: true
  },
  // EMAIL SERVICES
  postmark: {
    name: 'Postmark',
    category: 'Email Services',
    feedType: 'postmark',
    url: 'https://status.postmarkapp.com/',
    icon: 'fa-paper-plane',
    color: 'postmark-icon',
    useFeed: true
  },
  brevo: {
    name: 'Brevo',
    category: 'Email Services',
    feedType: 'brevo',
    url: 'https://status.brevo.com/',
    icon: 'fa-envelope-open',
    color: 'brevo-icon',
    useFeed: true
  },
  mailgun: {
    name: 'Mailgun',
    category: 'Email Services',
    api: 'https://status.mailgun.com/api/v2/status.json',
    url: 'https://status.mailgun.com/',
    icon: 'fa-envelope',
    color: 'mailgun-icon',
    corsEnabled: true
  },
  sendgrid: {
    name: 'SendGrid',
    category: 'Email Services',
    feedType: 'sendgrid',
    url: 'https://status.sendgrid.com/',
    icon: 'fa-envelope',
    color: 'sendgrid-icon',
    useFeed: true
  },
  sparkpost: {
    name: 'SparkPost',
    category: 'Email Services',
    feedType: 'sparkpost',
    url: 'https://status.sparkpost.com/',
    icon: 'fa-envelope',
    color: 'sparkpost-icon',
    useFeed: true
  },
  zoho: {
    name: 'Zoho',
    category: 'Email Services',
    feedType: 'zoho',
    url: 'https://status.zoho.com/',
    icon: 'fa-envelope',
    color: 'zoho-icon',
    useFeed: true
  },
  mailjet: {
    name: 'Mailjet',
    category: 'Email Services',
    feedType: 'mailjet',
    url: 'https://status.mailjet.com/',
    icon: 'fa-envelope',
    color: 'mailjet-icon',
    useFeed: true
  },
  mailersend: {
    name: 'MailerSend',
    category: 'Email Services',
    feedType: 'mailersend',
    url: 'https://status.mailersend.com/',
    icon: 'fa-paper-plane',
    color: 'mailersend-icon',
    useFeed: true
  },
  resend: {
    name: 'Resend',
    category: 'Email Services',
    feedType: 'resend',
    url: 'https://resend-status.com/',
    icon: 'fa-paper-plane',
    color: 'resend-icon',
    useFeed: true
  },
  smtp2go: {
    name: 'SMTP2GO',
    category: 'Email Services',
    feedType: 'smtp2go',
    url: 'https://smtp2gostatus.com/',
    icon: 'fa-envelope',
    color: 'smtp2go-icon',
    useFeed: true
  },
  sendlayer: {
    name: 'SendLayer',
    category: 'Email Services',
    feedType: 'sendlayer',
    url: 'https://status.sendlayer.com/',
    icon: 'fa-paper-plane',
    color: 'sendlayer-icon',
    useFeed: true
  },
  mailpoet: {
    name: 'MailPoet',
    category: 'Email Services',
    feedType: 'automattic',
    feedFilter: 'MailPoet Sending Service',
    url: 'https://automatticstatus.com/',
    icon: 'fa-envelope',
    color: 'wordpress-icon',
    useFeed: true
  },
  // COMMUNICATION
  discord: {
    name: 'Discord',
    category: 'Communication',
    api: 'https://discordstatus.com/api/v2/status.json',
    url: 'https://discordstatus.com/',
    icon: 'fa-discord',
    color: 'discord-icon',
    corsEnabled: true
  },
  slack: {
    name: 'Slack',
    category: 'Communication',
    feedType: 'slack',
    url: 'https://slack-status.com/',
    icon: 'fa-slack',
    color: 'slack-icon',
    useFeed: true
  },
  zoom: {
    name: 'Zoom',
    category: 'Communication',
    api: 'https://www.zoomstatus.com/api/v2/status.json',
    url: 'https://www.zoomstatus.com/',
    icon: 'fa-video',
    color: 'zoom-icon',
    corsEnabled: true
  },
  // HOSTING INFRASTRUCTURE (WordPress-related)
  wpcloudapi: {
    name: 'WP Cloud API',
    category: 'Hosting & Infrastructure',
    feedType: 'automattic',
    feedFilter: 'WP Cloud API',
    url: 'https://automatticstatus.com/',
    icon: 'fa-cloud',
    color: 'wordpress-icon',
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
    useFeed: true
  },
  // MEDIA & CONTENT
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
    useFeed: true
  },
  spotify: {
    name: 'Spotify',
    category: 'Media & Content',
    feedType: 'spotify',
    url: 'https://spotify.statuspage.io/',
    icon: 'fa-spotify',
    color: 'spotify-icon',
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
    useFeed: true
  },
  anthropic: {
    name: 'Anthropic (Claude)',
    category: 'AI & Machine Learning',
    feedType: 'anthropic',
    url: 'https://status.claude.com/',
    icon: 'fa-robot',
    color: 'anthropic-icon',
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
    useFeed: true
  },
  microsoftads: {
    name: 'Microsoft Advertising',
    category: 'Advertising',
    feedType: 'microsoftads',
    url: 'https://status.ads.microsoft.com/',
    icon: 'fa-microsoft',
    color: 'microsoft-icon',
    useFeed: true
  },
  metamarketingapi: {
    name: 'Meta: Marketing API',
    category: 'Advertising',
    feedType: 'metamarketingapi',
    url: 'https://metastatus.com/',
    icon: 'fa-facebook',
    color: 'facebook-icon',
    useFeed: true
  },
  metafbs: {
    name: 'Meta: Business Suite',
    category: 'Advertising',
    feedType: 'metafbs',
    url: 'https://metastatus.com/',
    icon: 'fa-facebook',
    color: 'facebook-icon',
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
    useFeed: true
  },
  flare: {
    name: 'Flare',
    category: 'Security',
    feedType: 'flare',
    url: 'https://status.flare.io/',
    icon: 'fa-shield-alt',
    color: 'flare-icon',
    useFeed: true
  }
};
