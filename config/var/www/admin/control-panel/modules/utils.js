// EngineScript Admin Dashboard - Utilities Module
// Input sanitization, validation, and UI helpers

export class DashboardUtils {
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
      // eslint-disable-next-line no-control-regex
      .replace(/[\x00-\x1F\x7F-\x9F]/g, "") // Remove all control characters
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
      // eslint-disable-next-line no-control-regex
      .replace(/[\x00-\x1F\x7F-\x9F]/g, "") // Remove control characters
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

  getAlertIcon(type) {
    const icons = {
      info: "fa-info-circle",
      warning: "fa-exclamation-triangle",
      error: "fa-exclamation-circle",
      success: "fa-check-circle",
    };
    return icons[type] || "fa-info-circle";
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
}
