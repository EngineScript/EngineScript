---
name: "PHP Version Test Failure"
about: "Automated issue created when the unit suite fails on a supported PHP version"
title: "PHP Version Test Failure"
labels: bug, php, tests, automated
assignees: []
---

## PHP Version Test Failure

The PHP Version Test job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the syntax check, the Composer install (locked, or the lowest versions `composer.json` allows), and the unit suite on one supported PHP version.

### Next steps

1. Run `composer test` on the PHP version and dependency lane that failed.
2. A failure only in the lowest lane points at a dependency constraint in `composer.json` that is too loose.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
