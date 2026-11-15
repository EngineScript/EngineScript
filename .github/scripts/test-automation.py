#!/usr/bin/env python3
"""Standard-library regression fixtures for the repository's automation scripts."""

# All mutation is confined to a temporary fixture repository on the runner.

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import re
import subprocess  # nosec B404
import tempfile
import unittest
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from types import ModuleType

# Bandit: every subprocess call in this file runs a fixed argument list without a shell.


def load_helper(filename: str) -> ModuleType:
    """Load a script of this directory as a module; its name has hyphens, so it cannot be imported."""
    spec = importlib.util.spec_from_file_location(filename, Path(__file__).with_name(filename))
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load {filename}.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


surface = load_helper("check-deployment-surface.py")


class DeploymentSurfaceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="es-automation-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        previous = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, previous)
        subprocess.run(["git", "init", "--quiet"], check=True)  # nosec B603 B607
        for name in surface.PANEL_FILES | surface.PANEL_REPOSITORY_ONLY:
            self.write(f"{surface.PANEL_DIR}/{name}", f"{name}\n")
        for name in surface.TOOLS_FILES | surface.TOOLS_REPOSITORY_ONLY:
            self.write(f"{surface.TOOLS_DIR}/{name}", f"{name}\n")
        self.write(f"{surface.PANEL_DIR}/index.html", "{ES_DASHBOARD_VER} {FONTAWESOME_VER}\n")
        self.write(f"{surface.PANEL_DIR}/dashboard.js", "import './modules/api.js?v={ES_DASHBOARD_VER}';\n")
        self.write(f"{surface.TOOLS_DIR}/phpsysinfo/phpsysinfo.ini", "php = SEDPHPVER\n")
        subprocess.run(["git", "add", "--all"], check=True)  # nosec B603 B607

    def write(self, name: str, content: str) -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def verify(self) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            count: int = surface.validate_surface(self.root)
        return count

    def test_allowlisted_surface_passes(self) -> None:
        self.assertEqual(len(surface.PANEL_FILES) + len(surface.TOOLS_FILES), self.verify())

    def test_stray_tracked_and_untracked_files_fail(self) -> None:
        for name in ("tests/ApiTest.php", "fixture.json", "notes.md", "panel.zip", "deploy.sh"):
            for track in (True, False):
                with self.subTest(name=name, tracked=track):
                    stray = f"{surface.PANEL_DIR}/{name}"
                    self.write(stray, "must not be served\n")
                    if track:
                        subprocess.run(["git", "add", "--", stray], check=True)  # nosec B603 B607
                    with self.assertRaises(ValueError):
                        self.verify()
                    subprocess.run(["git", "rm", "--cached", "--quiet", "--ignore-unmatch", "--", stray], check=True)  # nosec B603 B607
                    (self.root / stray).unlink()
        self.write(f"{surface.TOOLS_DIR}/tinyfilemanager/extra.php", "<?php\n")
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_allowlisted_file_fails(self) -> None:
        subprocess.run(["git", "rm", "--force", "--quiet", "--", f"{surface.PANEL_DIR}/api.php"], check=True)  # nosec B603 B607
        with self.assertRaises(ValueError):
            self.verify()

    def test_unsubstituted_placeholder_fails(self) -> None:
        for name, placeholder in (
            ("modules/api.js", "{ES_DASHBOARD_VER}"),
            ("dashboard.js", "{FONTAWESOME_VER}"),
            ("api.php", "{API_KEY}"),
            ("controllers/BaseController.php", "SEDCACHEDIR"),
        ):
            with self.subTest(name=name, placeholder=placeholder):
                path = f"{surface.PANEL_DIR}/{name}"
                original = (self.root / path).read_text(encoding="utf-8")
                self.write(path, f"{original}{placeholder}\n")
                with self.assertRaises(ValueError):
                    self.verify()
                self.write(path, original)

    def test_linked_file_fails(self) -> None:
        path = self.root / surface.PANEL_DIR / "favicon.png"
        path.unlink()
        try:
            path.symlink_to(self.root / surface.PANEL_DIR / "index.html")
        except OSError as error:
            self.skipTest(f"Symbolic links are not available here: {error}")
        with self.assertRaises(ValueError):
            self.verify()


REPOSITORY = Path(__file__).resolve().parents[2]
WORKFLOW = REPOSITORY / ".github" / "workflows" / "control-panel.yml"
TEMPLATES = REPOSITORY / ".github" / "ISSUE_TEMPLATE"
# The jobs of the plugin repositories' wp-compatibility-test.yml without their WordPress jobs. The
# integration suite runs on a real EngineScript server, not in this workflow (D-075).
PARITY_JOBS = (
    "phpcs",
    "phpmd",
    "psalm-analysis",
    "security-check",
    "phpstan",
    "rector",
    "javascript-tests",
    "lint",
    "unit-coverage",
    "php-version-test",
)
# "changes" decides on a pull request whether the parity jobs run; "control-panel-checks" needs every
# job and is the one required status check on master (Q-003).
FIRST_JOB = "changes"
LAST_JOB = "control-panel-checks"


def all_jobs() -> dict[str, str]:
    """Each job of the control panel workflow, with the text of its definition."""
    text = WORKFLOW.read_text(encoding="utf-8").split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([a-z0-9-]+):\n", text, flags=re.MULTILINE)
    return dict(zip(parts[1::2], parts[2::2], strict=True))


def workflow_jobs() -> dict[str, str]:
    """Return the parity jobs, without the two gate jobs."""
    return {job: body for job, body in all_jobs().items() if job not in (FIRST_JOB, LAST_JOB)}


class WorkflowTests(unittest.TestCase):
    def test_the_jobs_are_the_parity_jobs(self) -> None:
        self.assertEqual((FIRST_JOB, *PARITY_JOBS, LAST_JOB), tuple(all_jobs()))
        self.assertNotIn("integration-test", workflow_jobs())

    def test_each_parity_job_runs_only_when_the_panel_changed(self) -> None:
        for job, body in workflow_jobs().items():
            with self.subTest(job=job):
                self.assertIn(f"    needs: {FIRST_JOB}\n", body)
                self.assertIn("    if: ${{ needs.changes.outputs.relevant == 'true' }}\n", body)

    def test_the_last_job_needs_every_job_and_always_runs(self) -> None:
        body = all_jobs()[LAST_JOB]
        self.assertIn(f"    needs: [{', '.join((FIRST_JOB, *PARITY_JOBS))}]\n", body)
        self.assertIn("    if: ${{ always() }}\n", body)
        self.assertIn("failure|cancelled", body)

    def test_the_path_check_matches_the_push_paths(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")
        push = text.split("\n  push:\n", 1)[1].split("\n  pull_request:\n", 1)[0]
        paths = re.findall(r"^      - '([^']+)'$", push, flags=re.MULTILINE)
        expected = "|".join(path.replace("/**", "/*").replace("**/", "") for path in paths)
        case = re.search(r"^              (\S+)\)$", all_jobs()[FIRST_JOB], flags=re.MULTILINE)
        if case is None:
            self.fail("the path check has no case patterns")
        self.assertEqual(expected, case.group(1))
        self.assertNotIn("paths:", text.split("\n  pull_request:", 1)[1].split("\njobs:\n", 1)[0])

    def test_each_job_files_its_own_issue_from_an_existing_template(self) -> None:
        used = []
        for job, body in workflow_jobs().items():
            with self.subTest(job=job):
                templates = re.findall(r"filename: \.github/ISSUE_TEMPLATE/([a-z0-9-]+\.md)", body)
                self.assertEqual(1, len(templates), "one issue step per job")
                self.assertTrue((TEMPLATES / templates[0]).is_file(), templates[0])
                self.assertIn("issues: write", body)
                used.extend(templates)
        self.assertEqual(len(used), len(set(used)), "no template is shared")
        self.assertEqual(sorted(used), sorted(path.name for path in TEMPLATES.glob("*-failure.md")))
        self.assertEqual(len(PARITY_JOBS), len(used))

    def test_each_failure_stage_names_a_step_of_its_job(self) -> None:
        for job, body in workflow_jobs().items():
            with self.subTest(job=job):
                stages = set(re.findall(r"steps\.([a-z0-9_]+)\.outcome == 'failure'", body))
                steps = set(re.findall(r"^        id: ([a-z0-9_]+)$", body, flags=re.MULTILINE))
                self.assertTrue(stages, "the issue names the failed step")
                self.assertLessEqual(stages, steps)

    def test_every_action_is_pinned_to_a_commit(self) -> None:
        for job, body in all_jobs().items():
            for action in re.findall(r"uses: (\S+)", body):
                with self.subTest(job=job, action=action):
                    self.assertRegex(action, r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}$")


if __name__ == "__main__":
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("Run these regression fixtures in GitHub Actions, not locally.")
    unittest.main(verbosity=2)
