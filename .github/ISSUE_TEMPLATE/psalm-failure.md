---
name: "Psalm Failure"
about: "Automated issue created when the Psalm job fails"
title: "Psalm Static Analysis Failure"
labels: bug, psalm, static-analysis, automated
assignees: []
---

## Psalm Static Analysis Failure

The Psalm job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs Psalm at error level 1 (`composer psalm`) and its taint analysis (`composer psalm:taint`).

### Next steps

1. Run `composer psalm -- --no-cache` and `composer psalm:taint` locally; check the exit status, not only the last line.
2. A taint finding is a security question first: trace the source to the sink before changing anything.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
