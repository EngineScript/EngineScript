---
name: "Security Scan Failure"
about: "Automated issue created when the security scan fails"
title: "Security Scan Failure"
labels: bug, security, automated
assignees: []
---

## Security Scan Failure

The Security Scan job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the dependency vulnerability check (Symfony's security checker on `composer.lock`) and the scan of the control panel's PHP for shell or code execution, `unserialize()`, computed includes, `proc_open()` outside `SystemProcessRunner`, and superglobal reads outside `Request` and `Session`.

### Next steps

1. For a vulnerable dependency, update it within the declared range or report why it cannot be updated.
2. For a pattern finding, route the code through the panel's existing safe paths (`SystemCommand`, `Request`) instead of widening the scan.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
