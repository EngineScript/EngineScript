// EngineScript Admin Dashboard - dependency health checks

(() => {
  const FONT_AWESOME_LINK_ID = "fontawesome-css";
  const WARNING_ID = "fontawesome-warning";

  const showWarning = () => {
    if (document.getElementById(WARNING_ID)) {
      return;
    }

    const banner = document.createElement("div");
    banner.id = WARNING_ID;
    banner.className = "dependency-warning";
    banner.setAttribute("role", "status");
    banner.textContent = "Warning: Font Awesome icons failed to load. Run the EngineScript installer to configure frontend dependency versions.";
    document.body.prepend(banner);
  };

  const stylesheetLooksAvailable = (link) => {
    if (!link.sheet) {
      return false;
    }

    try {
      return link.sheet.cssRules.length > 0;
    } catch {
      // Cross-origin CSS can deny cssRules access even when loaded.
      return true;
    }
  };

  const checkFontAwesome = () => {
    const link = document.getElementById(FONT_AWESOME_LINK_ID);
    const href = link?.getAttribute("href") ?? link?.href ?? "";
    const hasVersionPlaceholder = href.includes("{FONTAWESOME_VER}") || href.includes("%7BFONTAWESOME_VER%7D");

    if (!link || hasVersionPlaceholder || !stylesheetLooksAvailable(link)) {
      showWarning();
    }
  };

  document.addEventListener("DOMContentLoaded", () => {
    const link = document.getElementById(FONT_AWESOME_LINK_ID);
    link?.addEventListener("error", showWarning, { once: true });

    window.addEventListener("load", checkFontAwesome, { once: true });
    setTimeout(checkFontAwesome, 3000);
  });
})();
