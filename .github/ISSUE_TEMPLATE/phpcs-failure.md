---
name: "PHPCS Failure"
about: "Automated issue created when the PHPCS job fails"
title: "PHPCS Code Standards Failure"
labels: bug, phpcs, code-quality, automated
assignees: []
---

## PHPCS Code Standards Failure

The PHPCS job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the PHPCS report (`vendor/bin/phpcs --standard=phpcs-extra.xml`: `phpcs.xml`, which Codacy also reads, plus the PHPCSExtra sniffs), the PHPCompatibility control, and PHP-CS-Fixer (`composer cs:check`, the PER Coding Style).

### Next steps

1. Run `composer phpcs` and `composer cs:check` locally.
2. Fix each reported line, or record why a rule does not fit this code in `phpcs.xml` (a PHPCSExtra rule: `phpcs-extra.xml`).
3. Until Phase 16 of the control panel review, the known findings (classes without a namespace, line length) make this job fail (`D-076`).

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
