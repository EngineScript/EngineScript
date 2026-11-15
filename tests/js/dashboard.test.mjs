/**
 * The dashboard's behavior as an administrator sees it: the real index.html,
 * dashboard.js, modules, and fontawesome-check.js, with API responses from the
 * panel's PHP (helpers.mjs). Timers are Node's mock timers (L6).
 */
import assert from "node:assert/strict";
import { afterEach, describe, it, mock } from "node:test";
import { loadPage, rendered, responses, settle } from "./helpers.mjs";

let page = null;

afterEach(() => {
  mock.timers.reset();
  page?.close();
  page = null;
});

const $ = (selector) => page.document.querySelector(selector);
const $$ = (selector) => [...page.document.querySelectorAll(selector)];
const text = (selector) => $(selector)?.textContent.replaceAll(/\s+/g, " ").trim() ?? null;
const failure = (name) => new Response(responses.failures[name].body, { status: responses.failures[name].status });

async function open(options = {}) {
  mock.timers.reset();
  mock.timers.enable({ apis: ["setInterval", "setTimeout", "Date"], now: new Date("2026-11-14T10:00:00Z") });
  page = await loadPage(options);
  return page;
}

async function goTo(name) {
  $(`.nav-item[data-page="${name}"] a`).click();
  await settle();
}

async function tick(ms) {
  mock.timers.tick(ms);
  await settle();
}

describe("loading", () => {
  it("starts the dashboard and loads only the overview", async () => {
    await open();

    assert.ok(page.dashboard);
    assert.deepEqual(page.errors, []);
    assert.deepEqual(page.calls.map((call) => `${call.method} ${call.url}`).toSorted(), [
      "GET /api/monitoring/uptime", "GET /api/monitoring/uptime/monitors", "GET /api/services/status"
    ]);
    assert.ok($("#loading-screen").classList.contains("es-hidden"));
    assert.ok(!$("#dashboard").classList.contains("es-hidden"));
  });

  it("shows each service's state and version", async () => {
    await open();
    const services = rendered("running", "GET /api/services/status");

    for (const name of ["nginx", "php", "mysql", "redis"]) {
      assert.equal(text(`#${name}-status .service-version`), `v${services[name].version}`, name);
      assert.ok($(`#${name}-status .service-status i`).classList.contains("online"), name);
    }
  });

  it("shows a stopped service offline and an unreadable version without a v", async () => {
    await open({ api: responses["services-stopped"] });

    assert.ok($("#mysql-status .service-status i").classList.contains("offline"));
    assert.equal(text("#mysql-status .service-version"), "Unknown");
    assert.ok($("#nginx-status .service-status i").classList.contains("online"));
  });
});

describe("error states", () => {
  it("a failed service status shows every service offline with Error", async () => {
    await open({ fetch: (call) => (call.url === "/api/services/status" ? failure("not-found") : undefined) });

    for (const name of ["nginx", "php", "mysql", "redis"]) {
      assert.ok($(`#${name}-status .service-status i`).classList.contains("offline"), name);
      assert.equal(text(`#${name}-status .service-version`), "Error", name);
    }
  });

  it("an uptime failure shows the API's own message", async () => {
    await open({ fetch: (call) => (call.url.startsWith("/api/monitoring/uptime") ? failure("rate-limited") : undefined) });

    assert.equal(text("#uptime-monitors"), "Rate limit exceeded");
  });

  it("a request that runs out of time says so", async () => {
    // After the first load, a server that never answers: the request ends only when its time
    // limit aborts it. The uptime card shows the reason; the limit is shortened for the test.
    let hang = false;
    await open({ fetch: (call) => (hang && call.url === "/api/monitoring/uptime" ? new Promise((_resolve, reject) => call.signal.addEventListener("abort", () => reject(call.signal.reason))) : undefined) });
    hang = true;
    page.dashboard.api.constructor.REQUEST_TIMEOUT_MS = 50;
    $("#refresh-btn").click();

    // AbortSignal.timeout runs on real time, which the mock timers leave alone
    const deadline = performance.now() + 3000;
    while (!/did not answer/.test(text("#uptime-monitors") ?? "") && performance.now() < deadline) {
      await settle(1);
    }
    assert.equal(text("#uptime-monitors"), "The server did not answer within 0.05 seconds");
  });

  it("the system page shows its error state with Retry, which loads again", async () => {
    let fail = true;
    await open({ fetch: (call) => (fail && call.url === "/api/system/info" ? failure("no-session") : undefined) });
    await goTo("system");
    assert.match(text("#system-info"), /Unable to Load System Information/);

    fail = false;
    $("#system-info .empty-state-action button").click();
    await settle();
    assert.equal($$("#system-info .info-item").length, 3);
  });

  it("a sites failure shows the error card", async () => {
    await open({ fetch: (call) => (call.url === "/api/sites" ? failure("not-found") : undefined) });
    await goTo("sites");

    assert.equal(text("#sites-grid .site-header"), "Error Loading Sites");
  });

  it("a session without storage shows the API's message on the uptime card", async () => {
    await open({ fetch: (call) => (call.url.startsWith("/api/monitoring/uptime") ? failure("no-session") : undefined) });

    assert.equal(text("#uptime-monitors"), "Session storage unavailable");
  });
});

describe("navigation", () => {
  it("shows the chosen page, its title, and loads its data", async () => {
    await open();
    await goTo("system");

    assert.ok(!$("#system-page").classList.contains("page-hidden"));
    assert.ok($("#overview-page").classList.contains("page-hidden"));
    assert.equal(text("#page-title"), "System Information");
    assert.ok($(".nav-item[data-page=\"system\"]").classList.contains("active"));
    assert.ok(page.calls.some((call) => call.url === "/api/system/info"));
  });

  it("shows the system information from the API as text", async () => {
    await open();
    await goTo("system");
    const info = rendered("running", "GET /api/system/info");

    assert.deepEqual($$("#system-info .info-item").map((item) => [...item.children].map((child) => child.textContent)), [
      ["OS:", info.os], ["Kernel:", info.kernel], ["Network:", info.network]
    ]);
  });

  it("announces the page change in the live region, which is not painted", async () => {
    await open();
    await goTo("tools");
    await tick(150);

    const region = $("#es-dashboard-live-region");
    assert.ok(region);
    assert.equal(region.getAttribute("aria-live"), "polite");
    assert.ok(region.classList.contains("sr-only"));
    assert.match(region.textContent, /Admin Tools/);
  });
});

describe("sites", () => {
  it("shows a card per valid site with its WordPress version and SSL", async () => {
    await open();
    await goTo("sites");
    const sites = rendered("running", "GET /api/sites").filter((site) => /^[a-zA-Z0-9.-]+$/.test(site.domain));

    const cards = $$("#sites-grid .site-card");
    assert.equal(cards.length, sites.length);
    assert.equal(cards[0].querySelector(".site-header").textContent.trim(), sites[0].domain);
    assert.match(cards[0].textContent, new RegExp(`WordPress: ${sites[0].wp_version}`));
    assert.match(cards[0].textContent, new RegExp(`SSL: ${sites[0].ssl_status}`));
  });

  it("leaves out a site whose name is not a domain, and inserts no markup from it", async () => {
    await open({ api: responses["sites-markup"] });
    await goTo("sites");

    const cards = $$("#sites-grid .site-card");
    assert.equal(cards.length, 1);
    assert.equal(cards[0].querySelector(".site-header").textContent.trim(), "good.example");
    assert.equal($("#sites-grid img"), null);
    assert.equal($("#sites-grid b"), null);
    assert.match(cards[0].textContent, /WordPress: <b>6\.8<\/b>/, "a version with markup arrives as text");
  });

  it("shows the empty state without sites", async () => {
    await open({ api: responses["no-sites"] });
    await goTo("sites");

    assert.match(text("#sites-grid"), /No WordPress sites/);
  });
});

describe("tools and caches", () => {
  it("hides the Adminer card when Adminer is not installed, and shows it when it is", async () => {
    await open();
    await goTo("tools");
    assert.ok($("#adminer-tool").classList.contains("es-hidden"));
    page.close();

    await open({ api: { "GET /api/tools/status": { status: 200, body: "{\"adminer\":true}" } } });
    await goTo("tools");
    assert.ok(!$("#adminer-tool").classList.contains("es-hidden"));
  });

  it("keeps the Adminer card hidden when the status cannot be loaded", async () => {
    await open({ fetch: (call) => (call.url === "/api/tools/status" ? failure("not-found") : undefined) });
    await goTo("tools");

    assert.ok($("#adminer-tool").classList.contains("es-hidden"));
  });

  it("shows the file manager's state", async () => {
    await open();
    await goTo("tools");
    const status = rendered("running", "GET /api/tools/filemanager/status");

    assert.equal($("#filemanager-tool").classList.contains("tool-unavailable"), !status.available);
    assert.ok($("#filemanager-status .status-indicator"));
  });

  it("lists each cache's state", async () => {
    await open();
    await goTo("tools");
    const caches = rendered("running", "GET /api/cache/status");

    const names = $$("#cache-status-list .cache-name").map((element) => element.textContent);
    assert.equal(names.length, 3);
    assert.match($("#cache-status-list").textContent, new RegExp(caches.redis.used_memory_human.replace(".", "\\.")));
  });
});

describe("clearing a cache", () => {
  it("disables the button while it runs, reports success, reloads the status, and keeps focus", async () => {
    await open();
    await goTo("tools");
    const button = $("[data-cache-type=\"redis\"]");
    button.focus();
    // Browsers take focus away from a disabled button and jsdom does not, so the test records the
    // focus call that gives it back.
    let refocused = 0;
    const focus = button.focus.bind(button);
    button.focus = () => {
      refocused += 1;
      focus();
    };
    button.click();

    assert.equal(button.disabled, true);
    assert.equal(button.getAttribute("aria-busy"), "true");
    await settle();

    assert.equal(button.disabled, false);
    assert.equal(button.getAttribute("aria-busy"), null);
    assert.equal(refocused, 1, "focus returns to the button");
    assert.equal(page.document.activeElement, button);
    assert.equal(text(".notification-toast"), "Cache cleared successfully");
    assert.ok($(".notification-toast").classList.contains("notification-success"));
    const statusLoads = page.calls.filter((call) => call.url === "/api/cache/status").length;
    assert.equal(statusLoads, 2, "once for the page, once after the clear");
  });

  it("clears all three with the all button", async () => {
    await open();
    await goTo("tools");
    $("[data-cache-type=\"all\"]").click();
    await settle();

    assert.deepEqual(page.calls.find((call) => call.method === "POST").body, { types: ["redis", "fastcgi", "opcache"] });
  });

  it("reports a failed clear with the result's message", async () => {
    await open({ api: { "POST /api/cache/clear redis": responses.failures["POST /api/cache/clear redis"] } });
    await goTo("tools");
    $("[data-cache-type=\"redis\"]").click();
    await settle();

    assert.ok($(".notification-toast").classList.contains("notification-error"));
    assert.equal(text(".notification-toast"), "Unable to clear cache");
  });

  it("removes the notification after five seconds", async () => {
    await open();
    await goTo("tools");
    $("[data-cache-type=\"redis\"]").click();
    await settle();
    assert.ok($(".notification-toast"));

    await tick(5000);
    assert.equal($(".notification-toast"), null);
  });

  it("loads a new token and retries once after the session ended", async () => {
    let posts = 0;
    await open({
      fetch: (call) => {
        if (call.method === "POST") {
          posts += 1;
          return posts === 1 ? failure("csrf-refused") : undefined;
        }
        return undefined;
      }
    });
    await goTo("tools");
    $("[data-cache-type=\"redis\"]").click();
    await settle();

    assert.equal(posts, 2);
    assert.equal(page.calls.filter((call) => call.url === "/api/csrf-token").length, 2, "the token was loaded again");
    assert.equal(text(".notification-toast"), "Cache cleared successfully");
  });

  it("retries only once when the new token is refused too", async () => {
    let posts = 0;
    await open({
      fetch: (call) => {
        if (call.method === "POST") {
          posts += 1;
          return failure("csrf-refused");
        }
        return undefined;
      }
    });
    await goTo("tools");
    $("[data-cache-type=\"redis\"]").click();
    await settle();

    assert.equal(posts, 2);
    assert.equal(text(".notification-toast"), "Invalid or missing CSRF token");
  });

  it("does not retry any other failure", async () => {
    let posts = 0;
    await open({
      fetch: (call) => {
        if (call.method === "POST") {
          posts += 1;
          return failure("rate-limited");
        }
        return undefined;
      }
    });
    await goTo("tools");
    $("[data-cache-type=\"redis\"]").click();
    await settle();

    assert.equal(posts, 1);
    assert.equal(text(".notification-toast"), "Rate limit exceeded");
  });
});

describe("uptime", () => {
  it("shows the setup instructions and empty counters without a key", async () => {
    await open();

    assert.match(text("#uptime-monitors"), /UptimeRobot not configured/);
    assert.match(text("#uptime-monitors"), /UPTIMEROBOT_API_KEY/);
    for (const id of ["total-monitors", "up-monitors", "down-monitors"]) {
      assert.equal(text(`#${id}`), "--", id);
    }
  });

  it("shows the counts and each monitor, inserting names and URLs as text", async () => {
    await open({ api: responses["uptime-configured"] });
    const summary = rendered("uptime-configured", "GET /api/monitoring/uptime");

    assert.equal(text("#total-monitors"), String(summary.total_monitors));
    assert.equal(text("#up-monitors"), String(summary.up));
    assert.equal(text("#down-monitors"), String(summary.down));
    const monitors = $$("#uptime-monitors .uptime-monitor");
    assert.equal(monitors.length, 3);
    assert.equal(monitors[1].querySelector("h4").textContent, "<b>Shop</b> & café");
    assert.equal(monitors[1].querySelector("b"), null, "no markup from the name");
    assert.doesNotMatch(monitors[2].querySelector(".monitor-url").textContent, /javascript:/, "an unsafe URL is not shown");
    assert.match(monitors[0].textContent, /99\.98%/);
  });

  it("shows the empty state when the account has no monitors", async () => {
    await open({ api: responses["uptime-empty"] });

    assert.match(text("#uptime-monitors"), /No Monitors Configured/);
  });
});

describe("timers", () => {
  it("runs the clock every second", async () => {
    await open();
    const first = text("#server-time");
    await tick(1000);

    assert.notEqual(text("#server-time"), first);
    assert.match(text("#server-time"), /^\d{2}:\d{2}:\d{2}$/);
  });

  it("refreshes the current page every five minutes", async () => {
    await open();
    const before = page.calls.filter((call) => call.url === "/api/services/status").length;
    await tick(5 * 60 * 1000);

    assert.equal(page.calls.filter((call) => call.url === "/api/services/status").length, before + 1);
    assert.ok($("#refresh-btn i").classList.contains("refresh-spinning"));
    await tick(1000);
    assert.ok(!$("#refresh-btn i").classList.contains("refresh-spinning"));
    // "Dashboard refreshed" is replaced by the service status before it is read: the region keeps
    // one announcement at a time.
    await tick(150);
    assert.match($("#es-dashboard-live-region").textContent, /^Service status loaded\./);
  });

  it("the refresh button reloads at once", async () => {
    await open();
    const before = page.calls.length;
    $("#refresh-btn").click();
    await settle();

    assert.ok(page.calls.length > before);
  });
});

describe("theme", () => {
  it("follows a saved theme, then the system's, and remembers a change", async () => {
    await open({ storage: { "dashboard-theme": "dark" } });
    assert.equal(page.document.documentElement.getAttribute("data-theme"), "dark");
    page.close();

    await open({ prefersDark: true });
    assert.equal(page.document.documentElement.getAttribute("data-theme"), "dark");
    $("#theme-toggle").click();
    assert.equal(page.document.documentElement.getAttribute("data-theme"), "light");
    assert.equal(page.window.localStorage.getItem("dashboard-theme"), "light");
  });
});

describe("keyboard", () => {
  const press = (target, key, init = {}) => {
    target.dispatchEvent(new page.window.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...init }));
  };

  it("arrows and digits change the page only while focus is in the navigation", async () => {
    await open();
    const link = $(".nav-item[data-page=\"overview\"] a");
    link.focus();
    press(link, "ArrowRight");
    await settle();
    assert.equal(page.dashboard.state.getCurrentPage(), "sites");
    assert.equal(page.document.activeElement, $(".nav-item[data-page=\"sites\"] a"), "focus follows");

    press($(".nav-item.active a"), "4");
    await settle();
    assert.equal(page.dashboard.state.getCurrentPage(), "tools");

    for (const key of ["1", "ArrowLeft", "ArrowRight"]) {
      press(page.document.body, key);
      await settle();
      assert.equal(page.dashboard.state.getCurrentPage(), "tools", `${key} outside the navigation changes nothing`);
    }
  });

  it("leaves F5, Ctrl+R, and modified digits to the browser", async () => {
    await open();
    const link = $(".nav-item[data-page=\"overview\"] a");
    for (const [key, init] of [["F5", {}], ["r", { ctrlKey: true }], ["2", { altKey: true }]]) {
      const event = new page.window.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...init });
      link.dispatchEvent(event);
      assert.equal(event.defaultPrevented, false, key);
    }
    assert.equal(page.dashboard.state.getCurrentPage(), "overview");
  });

  it("the mobile menu reports its state and Escape closes it", async () => {
    await open();
    const toggle = $("#mobile-menu-toggle");
    // jsdom applies dashboard.css's display: none but not the narrow-screen @media rule that
    // shows the toggle, and a hidden button cannot take focus; show it as that rule does.
    toggle.style.display = "block";
    assert.equal(toggle.getAttribute("aria-expanded"), "false");
    toggle.click();
    assert.equal(toggle.getAttribute("aria-expanded"), "true");
    assert.ok($("#sidebar").classList.contains("mobile-open"));

    press(page.document.body, "Escape");
    assert.equal(toggle.getAttribute("aria-expanded"), "false");
    assert.equal(page.document.activeElement, toggle);
  });
});

describe("the Font Awesome check", () => {
  it("shows no warning when the stylesheet loads", async () => {
    await open({ fontAwesome: "loaded" });
    assert.equal($("#fontawesome-warning"), null);
  });

  for (const state of ["blocked", "empty"]) {
    it(`warns when the stylesheet is ${state}`, async () => {
      await open({ fontAwesome: state });
      assert.match(text("#fontawesome-warning"), /could not be loaded from cdnjs\.cloudflare\.com/);
      assert.equal($("#fontawesome-warning").getAttribute("role"), "status");
    });
  }
});
