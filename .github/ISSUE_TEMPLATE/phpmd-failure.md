---
name: "PHPMD Failure"
about: "Automated issue created when the PHPMD job fails"
title: "PHPMD Code Quality Analysis Failure"
labels: bug, phpmd, code-quality, automated
assignees: []
---

## PHPMD Code Quality Analysis Failure

The PHPMD job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the PHPMD report (`composer phpmd`, `phpmd.xml`): complexity, size, design, naming, and unused code.

### Next steps

1. Run `composer phpmd` locally (exit code 2 means violations).
2. Fix the reported code; change a threshold in `phpmd.xml` only with the measured value recorded.
3. Until Phase 16 of the control panel review, the known naming findings make this job fail (`D-076`).

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
