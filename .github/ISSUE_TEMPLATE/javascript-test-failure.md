---
name: "JavaScript Test Failure"
about: "Automated issue created when the JavaScript tests fail"
title: "JavaScript Test Failure"
labels: bug, javascript, tests, automated
assignees: []
---

## JavaScript Test Failure

The JavaScript Tests job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the dashboard tests (`npm test`: `tests/js`, Node's test runner and jsdom, with API responses from the panel's PHP), the check that tests ran, and the intentionally failing control.

### Next steps

1. Run `npm test` locally; PHP must be on the PATH (the tests render API responses with `tests/js/render-api.php`).
2. A failure in `contract.test.mjs` means the scripts, `index.html`, and the API disagree: fix the side that changed.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
