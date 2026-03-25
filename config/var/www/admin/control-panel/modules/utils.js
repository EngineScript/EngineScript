// EngineScript Admin Dashboard - Utilities Module
// Input sanitization, validation, and UI helpers

export class DashboardUtils {
  static MAX_DASHBOARD_METRIC = 999999;

  sanitizeInput(input) {
    if (typeof input !== "string") {
      return String(input || "");
    }

    // Control character removal and length limiting
    // XSS prevention is handled by using textContent for all DOM output
    return String(input)
      // eslint-disable-next-line no-control-regex
      .replace(/[\x00-\x1F\x7F-\x9F]/g, "") // Remove all control characters
      .replace(/\s+/g, " ") // Normalize whitespace
      .trim()
      .substring(0, 1000); // Limit length
  }

  sanitizeNumeric(input, fallback = "0") {
    const cleaned = String(input || "").replace(/[^\d.-]/g, "");
    const parsed = parseFloat(cleaned);
    
    // Check if it's a valid number and within reasonable bounds
    if (isNaN(parsed) || !isFinite(parsed)) {
      return fallback;
    }
    
    // Reasonable bounds for dashboard metrics
    if (parsed < 0 || parsed > DashboardUtils.MAX_DASHBOARD_METRIC) {
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
    
    // Strip control characters and limit length before parsing
    const sanitized = String(input)
      // eslint-disable-next-line no-control-regex
      .replace(/[\x00-\x1F\x7F-\x9F]/g, "") // Remove control characters
      .trim()
      .substring(0, 2048); // Limit URL length

    // Use the native URL constructor for spec-compliant, ReDoS-safe validation.
    // This inherently blocks data:, javascript:, vbscript: and other dangerous schemes.
    try {
      const parsed = new URL(sanitized);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
        return fallback;
      }
    } catch {
      return fallback;
    }

    return sanitized;
  }

  setTextContent(elementId, content) {
    const element = document.getElementById(elementId);
    if (element) {
      const safeContent = content ?? "";
      element.textContent = String(safeContent);
    }
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

  showError(message) {
    // Sanitize error message
    const sanitizedMessage = this.sanitizeInput(message) || "An unknown error occurred";

    // Create a simple error notification
    const notification = document.createElement("div");
    notification.className = "notification-toast notification-error";
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
