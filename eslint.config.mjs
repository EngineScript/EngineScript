/**
 * ESLint configuration for the admin control panel's scripts and their tests:
 * ESLint's recommended rules, the panel's own formatting (checked by
 * @stylistic, set to the style the panel is written in), the plugin
 * repositories' rules that keep the code on modern JavaScript, and a check
 * that the panel's scripts use only features of the browsers it supports.
 */
import js from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";
import compat from "eslint-plugin-compat";
import unicorn from "eslint-plugin-unicorn";
import globals from "globals";

/*
 * Unicorn rules that move code to modern built-ins and patterns: the same
 * list as the plugin repositories. Left off, as there: prefer-module
 * (fontawesome-check.js is a classic script), no-null,
 * prevent-abbreviations, filename-case, no-array-for-each, and
 * prefer-query-selector.
 */
const modernizationRules = Object.fromEntries(
  [
    "consistent-date-clone",
    "new-for-builtins",
    "no-array-push-push",
    "no-document-cookie",
    "no-for-loop",
    "no-instanceof-builtins",
    "no-negation-in-equality-check",
    "no-new-array",
    "no-typeof-undefined",
    "no-unnecessary-polyfills",
    "no-useless-spread",
    "prefer-add-event-listener",
    "prefer-array-find",
    "prefer-array-flat",
    "prefer-array-flat-map",
    "prefer-array-index-of",
    "prefer-array-some",
    "prefer-at",
    "prefer-blob-reading-methods",
    "prefer-date-now",
    "prefer-dom-node-append",
    "prefer-dom-node-dataset",
    "prefer-dom-node-remove",
    "prefer-dom-node-text-content",
    "prefer-event-target",
    "prefer-global-this",
    "prefer-includes",
    "prefer-keyboard-event-key",
    "prefer-logical-operator-over-ternary",
    "prefer-modern-dom-apis",
    "prefer-modern-math-apis",
    "prefer-negative-index",
    "prefer-node-protocol",
    "prefer-number-properties",
    "prefer-object-from-entries",
    "prefer-optional-catch-binding",
    "prefer-regexp-test",
    "prefer-set-has",
    "prefer-spread",
    "prefer-string-replace-all",
    "prefer-string-slice",
    "prefer-string-starts-ends-with",
    "prefer-structured-clone",
    "prefer-type-error",
    "text-encoding-identifier-case",
    "throw-new-error",
  ].map((rule) => [`unicorn/${rule}`, "error"]),
);

export default [
  {
    ignores: [".private/**", "coverage/**", "node_modules/**", "vendor/**"],
  },
  js.configs.recommended,
  // The panel's formatting: two-space indentation, double quotes, semicolons.
  stylistic.configs.customize({
    indent: 2,
    quotes: "double",
    semi: true,
    jsx: false,
    braceStyle: "1tbs",
    arrowParens: true,
    commaDangle: "only-multiline",
  }),
  {
    languageOptions: {
      sourceType: "module",
      globals: { ...globals.browser },
    },
    linterOptions: {
      reportUnusedDisableDirectives: "error",
      reportUnusedInlineConfigs: "error",
    },
    plugins: { unicorn },
    rules: {
      ...modernizationRules,
      "logical-assignment-operators": ["error", "always"],
      "no-useless-concat": "error",
      "no-var": "error",
      "object-shorthand": "error",
      "prefer-arrow-callback": "error",
      "prefer-const": "error",
      "prefer-exponentiation-operator": "error",
      "prefer-numeric-literals": "error",
      "prefer-object-has-own": "error",
      "prefer-object-spread": "error",
      "prefer-rest-params": "error",
      "prefer-spread": "error",
      "prefer-template": "error",
    },
  },
  {
    // fontawesome-check.js is loaded as a classic script, not as a module.
    files: ["config/var/www/admin/control-panel/fontawesome-check.js"],
    languageOptions: {
      sourceType: "script",
    },
  },
  {
    // The browsers come from the "browserslist" entry in package.json.
    ...compat.configs["flat/recommended"],
    files: ["config/var/www/admin/control-panel/**/*.js"],
  },
  {
    files: ["tests/js/**"],
    languageOptions: {
      globals: { ...globals.node },
    },
  },
];
