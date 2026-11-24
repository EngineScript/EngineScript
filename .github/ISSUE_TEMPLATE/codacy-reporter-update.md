---
name: "Codacy Coverage Reporter Update"
about: "Automated issue created when a newer Codacy coverage reporter is out"
title: "Update the Codacy coverage reporter"
labels: dependencies, automated, maintenance
assignees: []
---

## Update the Codacy coverage reporter

Codacy released coverage reporter **{{ env.LATEST_VERSION }}** on {{ env.PUBLISHED }}. These
repositories pin an older version in their unit-coverage job:

{{ env.BEHIND }}

Dependabot cannot update it: the version and its SHA-512 sit in a `run:` step.

### The new values

- `CODACY_REPORTER_VERSION`: `{{ env.LATEST_VERSION }}`
- `CODACY_REPORTER_SHA512`: `{{ env.SHA512 }}`

The workflow checked this SHA-512 against the downloaded `codacy-coverage-reporter-linux` binary and
Codacy's published `codacy-coverage-reporter-linux.SHA512SUM`.

### Next steps

1. Read the release notes: <https://github.com/codacy/codacy-coverage-reporter/releases>.
2. In each repository listed above, change both values in the "Upload coverage to Codacy" step,
   in one pull request per repository.
3. Check that the pull request's unit-coverage job uploads the report and that Codacy shows the
   commit's coverage.

While this issue is open, the weekly check updates it instead of filing another. Close it once every
repository pins the new version.

---

*This issue was created automatically by the [Codacy Coverage Reporter Check]({{ env.WORKFLOW_URL }}) workflow.*
