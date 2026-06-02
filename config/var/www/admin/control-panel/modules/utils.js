// EngineScript Admin Dashboard - Utilities Module
// Input sanitization, validation, and UI helpers

export class DashboardUtils {
  static MAX_DASHBOARD_METRIC = 999999;

  static sanitizeInput(input) {
    if (typeof input !== "string") {
      return String(input ?? "");
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

  static setTextContent(elementId, content) {
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
    this.showNotification(message || "An unknown error occurred", "error");
  }

  showNotification(message, type = "info") {
    const allowedTypes = new Set(["success", "error", "info", "warning"]);
    const notificationType = allowedTypes.has(type) ? type : "info";
    const sanitizedMessage = DashboardUtils.sanitizeInput(message) || "Dashboard notification";
    const notification = document.createElement("div");
    notification.className = `notification-toast notification-${notificationType}`;
    notification.textContent = sanitizedMessage;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.remove();
    }, 5000);
  }
}
