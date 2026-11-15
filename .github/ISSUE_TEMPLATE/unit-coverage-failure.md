---
name: "Unit Coverage Failure"
about: "Automated issue created when unit test coverage falls below its minimum"
title: "Unit Test Coverage Below Minimum"
labels: bug, tests, coverage, automated
assignees: []
---

## Unit Test Coverage Below Minimum

The Unit Test Coverage job of the Control Panel workflow failed. A failure in setup or the
dependency installation does not show a problem in the code.

**Failure stage:** `{{ env.FAILURE_STAGE }}`

### Details

- **PHP version:** {{ env.PHP_VERSION }}
- **Date:** {{ date | date('YYYY-MM-DD HH:mm:ss') }}
- **Workflow run:** [View the logs and the diagnostic summary]({{ env.WORKFLOW_URL }})

### What the job checks

The job runs the unit suite with PCOV coverage and the minimum line coverage set in the job (`MINIMUM_LINE_COVERAGE`).

### Next steps

1. Run `vendor/bin/phpunit --testsuite unit --coverage-text` locally with PCOV.
2. Add unit tests for the new code; lower the minimum only with the measured value recorded.

### Validation

Run the job again after the fix. Keep its dependency installation and configured rules
unchanged.

---

*This issue was created automatically by the Control Panel workflow.*
