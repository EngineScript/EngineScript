// EngineScript Admin Dashboard - Utilities Module
// URL validation and UI helpers. Every value reaches the page through textContent, which
// never parses markup, so text needs no sanitizing; a URL does, because it becomes a link.

export class DashboardUtils {
  static sanitizeUrl(input, fallback = "") {
    if (typeof input !== "string") {
      return fallback;
    }

    // Strip control characters and limit length before parsing
    const sanitized = String(input)
      // eslint-disable-next-line no-control-regex
      .replaceAll(/[\x00-\x1F\x7F-\x9F]/g, "") // Remove control characters
      .trim()
      .slice(0, 2048); // Limit URL length

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
      site
      && typeof site === "object"
      && typeof site.domain === "string"
      && site.domain.length > 0
      && site.domain.length < 255
      && /^[a-zA-Z0-9.-]+$/.test(site.domain)
    ); // Basic domain validation
  }

  showError(message) {
    this.showNotification(message || "An unknown error occurred", "error");
  }

  showNotification(message, type = "info") {
    const allowedTypes = new Set(["success", "error", "info", "warning"]);
    const notificationType = allowedTypes.has(type) ? type : "info";
    const notification = document.createElement("div");
    notification.className = `notification-toast notification-${notificationType}`;
    notification.textContent = message || "Dashboard notification";

    document.body.append(notification);

    setTimeout(() => {
      notification.remove();
    }, 5000);
  }
}
