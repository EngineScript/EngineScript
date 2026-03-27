// EngineScript Admin Dashboard - Utilities Module
// Input sanitization, validation, and UI helpers

export class DashboardUtils {
  static MAX_DASHBOARD_METRIC = 999999;

  static sanitizeInput(input) {
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

  static sanitizeNumeric(input, fallback = "0") {
    const str = String(input ?? "").trim();

    // Build a well-formed numeric string: optional leading '-', digits, optional '.' and more digits.
    const match = str.match(/^(-)?(\d+)?(?:\.(\d+))?/);
    if (!match) {
      return fallback;
    }

    const sign = match[1] || "";
    const intPart = match[2] || "";
    const fracPart = match[3] || "";

    // Require at least one digit overall
    if (!intPart && !fracPart) {
      return fallback;
    }

    const normalized = sign + (intPart || "0") + (fracPart ? "." + fracPart : "");
    const parsed = parseFloat(normalized);

    // Check if it's a valid number and within reasonable bounds
    if (isNaN(parsed) || !isFinite(parsed)) {
      return fallback;
    }

    // Reasonable bounds for dashboard metrics
    if (parsed < 0 || parsed > DashboardUtils.MAX_DASHBOARD_METRIC) {
      return fallback;
    }

    return String(parsed);
  }

  static sanitizePercentage(input, fallback = "0%") {
    const cleaned = String(input || "").replace(/[^\d.%]/g, "");

    // Ensure the cleaned value is a syntactically valid percentage:
    // one or more digits, optional single decimal part, optional trailing '%'.
    const percentagePattern = /^\d+(\.\d+)?%?$/;
    if (!cleaned || !percentagePattern.test(cleaned)) {
      return fallback;
    }

    return cleaned;
  }

  static sanitizeUrl(input, fallback = "") {
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


  static isValidSite(site) {
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
    const sanitizedMessage = DashboardUtils.sanitizeInput(message) || "An unknown error occurred";

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
    // Basic validation to avoid undefined class names and malformed DOM
    if (!config || typeof config !== "object") {
      return null;
    }

    const {
      containerClass,
      iconClass,
      contentClass,
      messageText,
      timeText,
      timeClass,
      iconType = "fa-info-circle", // default icon when not specified
    } = config;

    // Ensure required class names are non-empty strings
    if (
      typeof containerClass !== "string" ||
      containerClass.length === 0 ||
      typeof iconClass !== "string" ||
      iconClass.length === 0 ||
      typeof contentClass !== "string" ||
      contentClass.length === 0 ||
      typeof timeClass !== "string" ||
      timeClass.length === 0
    ) {
      return null;
    }

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
    message.textContent = DashboardUtils.sanitizeInput(messageText ?? "");

    const time = document.createElement("span");
    time.className = timeClass;
    time.textContent = DashboardUtils.sanitizeInput(timeText ?? "");

    contentDiv.appendChild(message);
    contentDiv.appendChild(time);

    containerDiv.appendChild(iconDiv);
    containerDiv.appendChild(contentDiv);

    return containerDiv;
  }
}
