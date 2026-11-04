// EngineScript Admin Dashboard - dependency health checks
//
// Loaded as a classic, non-deferred script before the Font Awesome stylesheet, so the
// capturing error listener exists before the stylesheet can fail.

(() => {
  const FONT_AWESOME_LINK_ID = "fontawesome-css";
  const WARNING_ID = "fontawesome-warning";

  const showWarning = () => {
    if (!document.body) {
      document.addEventListener("DOMContentLoaded", showWarning, { once: true });
      return;
    }
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

  // A link's error event does not bubble, but a capturing listener on document sees it
  document.addEventListener("error", (event) => {
    if (event.target instanceof Element && event.target.id === FONT_AWESOME_LINK_ID) {
      showWarning();
    }
  }, true);

  // Whether an icon actually gets Font Awesome's font: the answer when the sheet's rules cannot be read
  const iconsStyled = () => {
    const probe = document.createElement("i");
    probe.className = "fas fa-check";
    probe.setAttribute("aria-hidden", "true");
    document.body.append(probe);
    const fontFamily = getComputedStyle(probe).fontFamily;
    probe.remove();
    return fontFamily.includes("Font Awesome");
  };

  const stylesheetLoaded = (link) => {
    if (!link.sheet) {
      return false;
    }

    try {
      return link.sheet.cssRules.length > 0;
    } catch {
      // The rules of a cross-origin sheet can be unreadable even when it loaded: unknown, so
      // look at what the browser applied instead of assuming success
      return iconsStyled();
    }
  };

  const checkFontAwesome = () => {
    const link = document.getElementById(FONT_AWESOME_LINK_ID);
    const href = link?.getAttribute("href") ?? "";
    const hasVersionPlaceholder = href.includes("{FONTAWESOME_VER}") || href.includes("%7BFONTAWESOME_VER%7D");

    if (!link || hasVersionPlaceholder || !stylesheetLoaded(link)) {
      showWarning();
    }
  };

  // Stylesheets delay the load event, so by then the Font Awesome sheet has loaded or failed
  globalThis.addEventListener("load", checkFontAwesome, { once: true });
})();
