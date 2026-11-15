---
name: "Rector Failure"
about: "Automated issue created when the Rector job fails"
title: "Rector Dry Run Failure"
labels: bug, rector, code-quality, automated
assignees: []
---

## Rector Dry Run Failure

The Rector job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the Rector dry run (`composer rector`, `rector.php`), which fails when any rule would change the code.

### Next steps

1. Run `composer rector` locally and read the proposed diff.
2. Apply the change, or skip the rule in `rector.php` with a comment giving this code's reason.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
