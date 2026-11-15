---
name: "PHPStan Failure"
about: "Automated issue created when the PHPStan job fails"
title: "PHPStan Static Analysis Failure"
labels: bug, phpstan, static-analysis, automated
assignees: []
---

## PHPStan Static Analysis Failure

The PHPStan job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs PHPStan at level max (`composer phpstan`, `phpstan.neon`).

### Next steps

1. Run `composer phpstan` locally.
2. Fix the type, not the report: no `@phpstan-ignore`, baseline, cast, or widened type.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
