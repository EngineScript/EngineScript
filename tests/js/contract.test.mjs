/**
 * Contract tests: the scripts, the page, and the API agree.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { afterEach, describe, it, mock } from "node:test";
import { JSDOM } from "jsdom";
import { loadPage, PANEL, rendered, responses, settle } from "./helpers.mjs";

const read = (file) => readFileSync(`${PANEL}${file}`, "utf8");
const scripts = ["dashboard.js", "modules/api.js", "modules/state.js", "modules/utils.js", "fontawesome-check.js"].map((file) => read(file)).join("\n");
const page = new JSDOM(read("index.html")).window.document;
const router = read("classes/Router.php");

// Patterns that scan the sources. Built from strings: a regex literal with an odd number of quote
// characters makes Lizard (which Codacy runs) misread the function around it.
const ROUTE = new RegExp("'(\\/[a-z/-]+)' => \\[\\s*self::(GET|POST)", "g");
const CREATED_ID = new RegExp("\\.id = \"([^\"]+)\"", "g");
const ID_LOOKUP = new RegExp("getElementById\\(\"([^\"]+)\"\\)", "g");
const TEMPLATED_ID_LOOKUP = new RegExp("getElementById\\(`\\$\\{(\\w+)\\}-status`\\)", "g");
const SELECTOR = new RegExp("querySelector(?:All)?\\(\"([^\"]+)\"\\)", "g");
const GET_CALL = new RegExp("getApiData\\(\"\\/api(\\/[^\"]+)\"\\)", "g");
const POST_CALL = new RegExp("postApiData\\(\"\\/api(\\/[^\"]+)\"", "g");

let loaded = null;
afterEach(() => {
  mock.timers.reset();
  loaded?.close();
  loaded = null;
});

/** Every route in the Router's table, with the methods it allows. */
const routes = new Map(
  [...router.matchAll(ROUTE)].map(([, route, kind]) => [route, kind === "GET" ? ["GET", "HEAD"] : ["POST"]])
);

describe("selectors", () => {
  it("every id the scripts look up is in index.html or created by the scripts", () => {
    const created = new Set([...scripts.matchAll(CREATED_ID)].map(([, id]) => id));
    const ids = new Set([...scripts.matchAll(ID_LOOKUP)].map(([, id]) => id));
    const templated = [...scripts.matchAll(TEMPLATED_ID_LOOKUP)];

    assert.ok(ids.size > 15, "the scan finds the lookups");
    for (const id of ids) {
      assert.ok(page.getElementById(id) || created.has(id), `#${id}`);
    }
    assert.ok(templated.length > 0);
    for (const service of ["nginx", "php", "mysql", "redis"]) {
      assert.ok(page.getElementById(`${service}-status`), `#${service}-status`);
    }
  });

  it("every class and attribute selector the scripts use matches the page or the scripts' own markup", async () => {
    mock.timers.enable({ apis: ["setInterval", "setTimeout", "Date"] });
    loaded = await loadPage({ api: responses["uptime-configured"] });
    for (const name of ["sites", "system", "tools", "overview"]) {
      loaded.document.querySelector(`.nav-item[data-page="${name}"] a`).click();
      await settle();
    }

    const selectors = new Set([...scripts.matchAll(SELECTOR)].map(([, selector]) => selector));
    assert.ok(selectors.size > 8);
    for (const selector of selectors) {
      assert.ok(loaded.document.querySelector(selector), selector);
    }
  });

  it("the controls the scripts wire up are in the page", () => {
    assert.deepEqual([...page.querySelectorAll("[data-cache-type]")].map((button) => button.dataset.cacheType).toSorted(), ["all", "fastcgi", "opcache", "redis"]);
    assert.deepEqual([...page.querySelectorAll(".nav-item")].map((item) => item.dataset.page), ["overview", "sites", "system", "tools"]);
    for (const name of ["overview", "sites", "system", "tools"]) {
      assert.ok(page.getElementById(`${name}-page`), `#${name}-page`);
    }
  });
});

describe("endpoints", () => {
  it("every endpoint the scripts call is a route, with the method the Router allows", () => {
    const gets = [...scripts.matchAll(GET_CALL)].map(([, path]) => path);
    const posts = [...scripts.matchAll(POST_CALL)].map(([, path]) => path);

    assert.ok(routes.size === 10, "the scan reads the route table");
    assert.ok(gets.length >= 7 && posts.length >= 1);
    for (const path of gets) {
      assert.ok(routes.get(path)?.includes("GET"), `GET ${path}`);
    }
    for (const path of posts) {
      assert.ok(routes.get(path)?.includes("POST"), `POST ${path}`);
    }
    assert.ok(routes.get("/csrf-token")?.includes("GET"), "the token route");
    assert.match(scripts, /"\/api\/csrf-token"/);
  });
});

describe("response fields", () => {
  /** The fields the scripts read, by response; each is checked against the controller's output. */
  const fieldsRead = {
    "GET /api/services/status": (r) => ["nginx", "php", "mysql", "redis"].flatMap((s) => [r[s].version, r[s].online]),
    "GET /api/system/info": (r) => [r.os, r.kernel, r.network],
    "GET /api/tools/status": (r) => [r.adminer],
    "GET /api/tools/filemanager/status": (r) => [r.available, r.config_exists, r.url, r.version],
    "GET /api/cache/status": (r) => [r.redis.available, r.fastcgi.available, r.opcache.available],
    "GET /api/csrf-token": (r) => [r.csrf_token, r.token_name],
    "GET /api/monitoring/uptime": (r) => [r.enabled, r.reason],
    "GET /api/monitoring/uptime/monitors": (r) => [r.enabled, r.monitors]
  };

  for (const [key, fields] of Object.entries(fieldsRead)) {
    it(`${key} has every field the scripts read`, () => {
      for (const value of fields(rendered("running", key))) {
        assert.notEqual(value, undefined);
      }
    });
  }

  it("each configured uptime field and site field the scripts read is produced", () => {
    const summary = rendered("uptime-configured", "GET /api/monitoring/uptime");
    for (const field of ["enabled", "total_monitors", "up", "down"]) {
      assert.notEqual(summary[field], undefined, field);
      assert.match(scripts, new RegExp(`summary\\.${field}`), `the scripts read summary.${field}`);
    }
    for (const monitor of rendered("uptime-configured", "GET /api/monitoring/uptime/monitors").monitors) {
      for (const field of ["name", "url", "status", "status_text", "uptime_day"]) {
        assert.ok(field in monitor, field);
        assert.match(scripts, new RegExp(`monitor\\.${field}`), `the scripts read monitor.${field}`);
      }
    }
    for (const site of rendered("running", "GET /api/sites")) {
      for (const field of ["domain", "wp_version", "ssl_status"]) {
        assert.ok(field in site, field);
        assert.match(scripts, new RegExp(`site\\.${field}`), `the scripts read site.${field}`);
      }
    }
  });

  it("the CSRF error the scripts recognize is the one the server sends", () => {
    const sent = rendered("failures", "csrf-refused").error;
    assert.equal(sent, "Invalid or missing CSRF token");
    assert.match(read("modules/api.js"), new RegExp(`CSRF_ERROR = "${sent}"`));
  });
});

describe("the CSRF flow", () => {
  it("a POST carries the session's token in X-CSRF-Token, loaded on first use", async () => {
    mock.timers.enable({ apis: ["setInterval", "setTimeout", "Date"] });
    loaded = await loadPage();
    await loaded.dashboard.clearCache("redis", null);

    const token = rendered("running", "GET /api/csrf-token").csrf_token;
    const order = loaded.calls.map((call) => `${call.method} ${call.url}`);
    assert.ok(order.indexOf("GET /api/csrf-token") < order.indexOf("POST /api/cache/clear"));
    const post = loaded.calls.find((call) => call.method === "POST");
    assert.equal(post.headers["X-CSRF-Token"], token);
    assert.equal(post.headers["Content-Type"], "application/json");
    assert.deepEqual(post.body, { types: ["redis"] });
    assert.equal(post.credentials, "include");
  });
});
