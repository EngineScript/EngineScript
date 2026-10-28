#!/usr/bin/env python3
"""Standard-library regression fixtures for the repository's automation scripts.

All mutation is confined to a temporary fixture repository on the runner.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
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


if __name__ == "__main__":
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("Run these regression fixtures in GitHub Actions, not locally.")
    unittest.main(verbosity=2)
