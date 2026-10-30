#!/usr/bin/env python3
"""Verify the files under the panel's deployed directories against a tracked allowlist.

The installer copies config/var/www/admin/control-panel/ into the web root with
`cp -a`, and copies two named files from config/var/www/admin/tools/ into the
tools it installs. Every file in those directories is served, so nothing else
may live there: no test, fixture, development file, archive, or executable.
"""

from __future__ import annotations

import argparse
import re
import subprocess  # nosec B404
from pathlib import Path

# Bandit: every subprocess call in this file runs a fixed argument list without a shell.

PANEL_DIR = "config/var/www/admin/control-panel"
TOOLS_DIR = "config/var/www/admin/tools"

# Copied whole into /var/www/admin/control-panel/ by
# scripts/install/tools/frontend/admin-control-panel-install.sh.
PANEL_FILES = {
    "api.php",
    "classes/ApiResponder.php",
    "classes/CommandRunner.php",
    "classes/Request.php",
    "classes/Router.php",
    "classes/SecurityLogger.php",
    "classes/Session.php",
    "classes/SystemCommand.php",
    "classes/SystemProcessRunner.php",
    "classes/UptimeRobotAPI.php",
    "controllers/BaseController.php",
    "controllers/CacheController.php",
    "controllers/CsrfController.php",
    "controllers/FileManagerController.php",
    "controllers/ServiceController.php",
    "controllers/SiteController.php",
    "controllers/SystemController.php",
    "controllers/ToolsController.php",
    "controllers/UptimeController.php",
    "dashboard.css",
    "dashboard.js",
    "favicon.png",
    "fontawesome-check.js",
    "index.html",
    "modules/api.js",
    "modules/state.js",
    "modules/utils.js",
}

# Tracked beside the panel for the repository's readers; the install script removes them from the web root.
PANEL_REPOSITORY_ONLY = {"LICENSE", "README.md"}

# Copied by name into the installed tools by tiny-file-manager-install.sh and phpsysinfo-install.sh.
TOOLS_FILES = {
    "phpsysinfo/phpsysinfo.ini",
    "tinyfilemanager/config.php",
}

# Tracked beside them for the repository's readers; no install script copies it.
TOOLS_REPOSITORY_ONLY = {"README.md"}

# SED placeholders are glued to the text before them ("php-fpmSEDPHPVER"), so no word boundary is required.
PLACEHOLDER_PATTERN = re.compile(r"\{[A-Z][A-Z0-9_]*\}|(?<![A-Z])SED[A-Z][A-Z0-9_]*")

# Every placeholder that may appear in a deployed file, and why it is there.
ALLOWED_PLACEHOLDERS = {
    # Substituted by admin-control-panel-install.sh, which fails if any is left.
    (f"{PANEL_DIR}/index.html", "{ES_DASHBOARD_VER}"),
    (f"{PANEL_DIR}/dashboard.js", "{ES_DASHBOARD_VER}"),
    # Substituted in the Font Awesome CDN URL; the HTML comment that explains it keeps the name.
    (f"{PANEL_DIR}/index.html", "{FONTAWESOME_VER}"),
    # The script looks for the unsubstituted name to detect a failed substitution.
    (f"{PANEL_DIR}/fontawesome-check.js", "{FONTAWESOME_VER}"),
    # Substituted by phpsysinfo-install.sh.
    (f"{TOOLS_DIR}/phpsysinfo/phpsysinfo.ini", "SEDPHPVER"),
}


def listed_files(root: Path, directory: str) -> set[str]:
    """List tracked and untracked, not ignored, files under a directory, relative to it."""
    listing = (
        subprocess.run(  # nosec B603 B607
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", directory],
            cwd=root,
            check=True,
            capture_output=True,
        )
        .stdout.decode("utf-8")
        .split("\0")
    )
    prefix = f"{directory}/"
    return {name[len(prefix) :] for name in listing if name.startswith(prefix)}


def check_file_set(directory: str, actual: set[str], allowed: set[str]) -> None:
    """Refuse a file outside the allowlist, and an allowlisted file that is missing."""
    extra = sorted(actual - allowed)
    missing = sorted(allowed - actual)
    if extra:
        raise ValueError(f"Not allowed under {directory}/: " + ", ".join(extra))
    if missing:
        raise ValueError(f"Missing from {directory}/: " + ", ".join(missing))


def check_regular_files(root: Path, names: set[str]) -> None:
    """Refuse a linked file or a name that is not a regular file."""
    for name in sorted(names):
        path = root / name
        if any(part.is_symlink() for part in (path, *path.parents)) or not path.is_file():
            raise ValueError(f"Not a regular file: {name}")


def check_placeholders(root: Path, names: set[str]) -> int:
    """Refuse a placeholder that the installer neither substitutes nor keeps on purpose."""
    found = 0
    problems = []
    for name in sorted(names):
        content = (root / name).read_bytes()
        if b"\0" in content:
            continue
        for placeholder in sorted(set(PLACEHOLDER_PATTERN.findall(content.decode("utf-8")))):
            found += 1
            if (name, placeholder) not in ALLOWED_PLACEHOLDERS:
                problems.append(f"{name}: {placeholder}")
    if problems:
        raise ValueError("Placeholders the installer does not substitute: " + ", ".join(problems))
    return found


def validate_surface(root: Path) -> int:
    """Check both deployed directories; return the number of files verified."""
    panel = listed_files(root, PANEL_DIR)
    tools = listed_files(root, TOOLS_DIR)
    check_file_set(PANEL_DIR, panel, PANEL_FILES | PANEL_REPOSITORY_ONLY)
    check_file_set(TOOLS_DIR, tools, TOOLS_FILES | TOOLS_REPOSITORY_ONLY)
    deployed = {f"{PANEL_DIR}/{name}" for name in PANEL_FILES} | {f"{TOOLS_DIR}/{name}" for name in TOOLS_FILES}
    repository_only = {f"{PANEL_DIR}/{name}" for name in PANEL_REPOSITORY_ONLY} | {
        f"{TOOLS_DIR}/{name}" for name in TOOLS_REPOSITORY_ONLY
    }
    check_regular_files(root, deployed | repository_only)
    placeholders = check_placeholders(root, deployed)
    print(f"Placeholders found, each substituted or kept on purpose: {placeholders}")
    return len(deployed)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    count = validate_surface(Path.cwd())
    print(f"Verified {count} deployed files against the allowlist.")
