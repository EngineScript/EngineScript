---
name: "Lint Failure"
about: "Automated issue created when the lint job fails"
title: "Lint Failure"
labels: bug, lint, code-quality, automated
assignees: []
---

## Lint Failure

The Lint job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs ESLint (with the modern-JavaScript rules and the supported-browser check), Stylelint, html-validate, markdownlint, Ruff, mypy, the repository script tests, the deployment check, yamllint, actionlint, and zizmor.

### Next steps

1. Run the failed step's command locally (`npm run lint:js`, `npm run lint:css`, `npm run lint:html`, `npm run lint:md`, `ruff check .github/scripts`, `mypy`, `yamllint -c .yamllint.yml`, `actionlint`, `zizmor --offline .github/workflows`).
2. The deployment check fails when a file appears in the deployed control panel directory that its allowlist does not name.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
