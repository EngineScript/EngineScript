/**
 * Helpers for the dashboard script tests.
 *
 * Each page load installs the control panel into a temporary directory the way
 * admin-control-panel-install.sh does (README.md and LICENSE left out, the Font
 * Awesome URL and {ES_DASHBOARD_VER} substituted), with a version of its own, so
 * the browser-style module URLs (./modules/api.js?v=<version>) give every load
 * fresh modules. jsdom renders the real index.html; a resource loader serves the
 * panel's own files and answers the Font Awesome stylesheet as the test asks, so
 * fontawesome-check.js runs as in a browser. jsdom does not run module scripts,
 * so the helper imports the real dashboard.js with jsdom's window as the global
 * scope and fires DOMContentLoaded, as a browser does after module scripts.
 *
 * API responses come from the panel's PHP (render-api.php). The page's fetch()
 * is answered from them and every call is recorded.
 */
import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { JSDOM, VirtualConsole, requestInterceptor } from "jsdom";

export const PANEL = fileURLToPath(new URL("../../config/var/www/admin/control-panel/", import.meta.url));
const VARIABLES = readFileSync(new URL("../../enginescript-variables.txt", import.meta.url), "utf8");
export const FONTAWESOME_VER = /^FONTAWESOME_VER="([^"]+)"/m.exec(VARIABLES)[1];
export const BASE = "https://admin.example.test";
const FONT_AWESOME_URL = `https://cdnjs.cloudflare.com/ajax/libs/font-awesome/${FONTAWESOME_VER}/css/all.min.css`;
const FONT_AWESOME_CSS = ".fas{font-family:\"Font Awesome 7 Free\"}.fa-check:before{content:\"\\f00c\"}";

/** API responses rendered by the panel's PHP: scenario => "METHOD /api/path" => {status, body}. */
export const responses = JSON.parse(
  execFileSync("php", ["-d", "display_errors=stderr", fileURLToPath(new URL("render-api.php", import.meta.url))], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"]
  })
);

let installs = 0;

/**
 * The panel as the installer leaves it, in a new temporary directory.
 *
 * @return {{dir: string, version: string}} The directory and the dashboard version.
 */
export function install() {
  installs += 1;
  const dir = mkdtempSync(path.join(tmpdir(), "es-panel-"));
  cpSync(PANEL, dir, { recursive: true });
  rmSync(path.join(dir, "README.md"), { force: true });
  rmSync(path.join(dir, "LICENSE"), { force: true });
  const version = `11.14.2026-test${installs}`;
  for (const file of ["index.html", "dashboard.js"]) {
    const target = path.join(dir, file);
    let text = readFileSync(target, "utf8");
    if (file === "index.html") {
      text = text.replaceAll(
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/{FONTAWESOME_VER}/css/all.min.css",
        FONT_AWESOME_URL
      );
    }
    writeFileSync(target, text.replaceAll("{ES_DASHBOARD_VER}", version));
  }

  return { dir, version };
}

const TYPES = { ".css": "text/css", ".js": "text/javascript", ".png": "image/png", ".html": "text/html" };

/**
 * Answers every request the page makes: the installed panel's files, and the Font
 * Awesome stylesheet as the test says. Nothing reaches the network.
 */
function panelInterceptor(dir, fontAwesome, requested) {
  return requestInterceptor((request) => {
    requested.push(request.url);
    if (request.url.startsWith("https://cdnjs.cloudflare.com/")) {
      if (fontAwesome === "blocked") {
        // A failed load fires the link's error event, as when cdnjs is down or blocked
        return new Response("", { status: 503 });
      }
      return new Response(fontAwesome === "empty" ? "" : FONT_AWESOME_CSS, { headers: { "Content-Type": "text/css" } });
    }
    const { pathname } = new URL(request.url);
    // Module scripts are imported by the helper; nothing else leaves the panel.
    if (!request.url.startsWith(BASE) || (pathname.endsWith(".js") && pathname !== "/fontawesome-check.js")) {
      return new Response("", { status: 404 });
    }
    return new Response(readFileSync(path.join(dir, decodeURIComponent(pathname))), {
      headers: { "Content-Type": TYPES[path.extname(pathname)] ?? "application/octet-stream" }
    });
  });
}

const GLOBALS = [
  "window", "document", "location", "localStorage", "Element", "HTMLElement", "HTMLButtonElement",
  "Node", "Event", "KeyboardEvent", "MouseEvent", "CustomEvent", "getComputedStyle", "matchMedia"
];

/**
 * Load the dashboard.
 *
 * @param {Object} options
 * @param {Object} [options.api]         - Responses by "METHOD /api/path", over the running server's.
 * @param {Function} [options.fetch]     - Answers a request before the responses do (return undefined to pass).
 * @param {string} [options.fontAwesome] - "loaded", "empty", or "blocked".
 * @param {Object} [options.storage]     - localStorage entries before the load.
 * @param {boolean} [options.prefersDark] - The system color scheme.
 * @return {Promise<Object>} The window, the document, the dashboard, the recorded calls, and close().
 */
export async function loadPage({ api = {}, fetch: answer = null, fontAwesome = "loaded", storage = {}, prefersDark = false } = {}) {
  const { dir, version } = install();
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on("jsdomError", (error) => errors.push(String(error.message ?? error)));
  const requested = [];
  const dom = new JSDOM(readFileSync(path.join(dir, "index.html"), "utf8"), {
    url: `${BASE}/`,
    runScripts: "dangerously",
    resources: { interceptors: [panelInterceptor(dir, fontAwesome, requested)] },
    pretendToBeVisual: true,
    virtualConsole
  });
  const { window } = dom;
  for (const [key, value] of Object.entries(storage)) {
    window.localStorage.setItem(key, value);
  }
  window.matchMedia = (query) => ({
    matches: prefersDark && query.includes("dark"),
    media: query,
    addEventListener() {},
    removeEventListener() {}
  });

  const table = { ...responses.running, ...api };
  const calls = [];
  const fetchStub = async (url, init = {}) => {
    const method = (init.method ?? "GET").toUpperCase();
    const pathname = new URL(url, BASE).pathname + new URL(url, BASE).search;
    let body = null;
    if (typeof init.body === "string") {
      body = JSON.parse(init.body);
    }
    const call = { method, url: pathname, headers: { ...init.headers }, body, credentials: init.credentials, signal: init.signal };
    calls.push(call);
    const custom = answer?.(call);
    if (custom !== undefined) {
      return custom;
    }
    const key = method === "POST" && pathname === "/api/cache/clear" ? `POST /api/cache/clear ${(body?.types ?? []).join(",")}` : `${method} ${pathname}`;
    const rendered = table[key];
    if (!rendered) {
      return new Response("{\"error\":\"Endpoint not found\"}", { status: 404, headers: { "Content-Type": "application/json" } });
    }
    return new Response(rendered.body, { status: rendered.status, headers: { "Content-Type": "application/json; charset=UTF-8" } });
  };

  const saved = new Map(GLOBALS.map((name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)]));
  const savedFetch = globalThis.fetch;
  for (const name of GLOBALS) {
    Object.defineProperty(globalThis, name, { value: window[name], configurable: true, writable: true });
  }
  globalThis.fetch = fetchStub;
  delete globalThis.engineScriptDashboard;

  // Stylesheets and fontawesome-check.js load before the page's load event
  await new Promise((resolve) => {
    if (window.document.readyState === "complete") {
      resolve();
    } else {
      window.addEventListener("load", resolve, { once: true });
    }
  });

  await import(`${pathToFileURL(path.join(dir, "dashboard.js")).href}?v=${version}`);
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
  await settle();

  return {
    window,
    document: window.document,
    dashboard: globalThis.engineScriptDashboard,
    calls,
    errors,
    requested,
    version,
    close() {
      delete globalThis.engineScriptDashboard;
      globalThis.fetch = savedFetch;
      for (const [name, descriptor] of saved) {
        if (descriptor) {
          Object.defineProperty(globalThis, name, descriptor);
        } else {
          delete globalThis[name];
        }
      }
      window.close();
      rmSync(dir, { recursive: true, force: true });
    }
  };
}

/**
 * Let pending promises and fetch answers run.
 */
export async function settle(rounds = 20) {
  for (let i = 0; i < rounds; i += 1) {
    await new Promise((resolve) => {
      setImmediate(resolve);
    });
  }
}

/**
 * The JSON body of a rendered response.
 */
export function rendered(scenario, key) {
  return JSON.parse(responses[scenario][key].body);
}
