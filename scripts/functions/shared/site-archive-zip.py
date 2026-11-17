#!/usr/bin/env python3
"""Write an EngineScript site archive, a ZIP, from files and pipes in the current folder."""

# build_site_archive in enginescript-site-archive.sh runs this in its staging folder. The database
# dump and the files archive are piped in as they are made, so neither is written to disk before
# it is in the ZIP. The zip command cannot do that: it can only add files that already exist, which
# put every part on disk twice while an archive was built.
#
# Usage: site-archive-zip.py <output.zip> <entry>=<source>... [--status <entry> <file> <highest>]...
#
# The output, every source, and every status file are names of files in the current folder; any
# other path is refused, so the tool reads, writes, and removes nothing outside that folder. A
# source is a file or a named pipe. Every entry is stored without compression, because the parts
# are compressed already, and the entry of each folder is written as zip -r wrote it. Entries are
# written in the order given.
#
# --status names the file in which the command that feeds an entry leaves its exit status. Once
# the entry has been read to its end, a status above <highest>, or a missing status file, stops the
# archive there, so a failed dump is not followed by archiving all the site's files.
#
# Exit status: 0 the archive is written; 1 it could not be read or written; 2 wrong arguments;
# 3 a command that feeds an entry failed. The output file is removed unless the status is 0.

import argparse
import shutil
import stat
import sys
import time
import zipfile
from pathlib import Path

COPY_CHUNK_BYTES = 1024 * 1024
EXIT_IO_ERROR = 1
EXIT_SOURCE_FAILED = 3
# In a ZIP entry's external attributes: the Unix mode sits in the high 16 bits, and the low byte
# holds the MS-DOS attributes, where 0x10 marks a folder
UNIX_MODE_SHIFT = 16
MSDOS_FOLDER = 0x10


class SourceFailedError(Exception):
    """The command that feeds an entry did not end well."""


def local_file(text: str) -> Path:
    """Return the file of that name in the current folder; refuse a path that leads elsewhere."""
    name = Path(text).name
    if name != text or name in {"", ".", ".."}:
        raise ValueError(f"not the name of a file in the current folder: {text}")
    return Path(name)


def entry_name(text: str) -> str:
    """Return a name for an entry in the archive; refuse one that would unzip outside its folder."""
    parts = text.split("/")
    if not text or text.startswith("/") or "" in parts or ".." in parts or "." in parts:
        raise ValueError(f"not a relative entry name: {text}")
    return text


def read_entry(text: str) -> tuple[str, Path]:
    """Split <entry>=<source> into the entry's name and its source."""
    name, separator, source = text.partition("=")
    if not separator:
        raise ValueError(f"not <entry>=<source>: {text}")
    return entry_name(name), local_file(source)


def read_status(name: str, file: str, highest: str) -> tuple[str, Path, int]:
    """Check one --status: the entry, its status file, and the highest status accepted."""
    if not highest.isdigit():
        raise ValueError(f"not a status number: {highest}")
    return entry_name(name), local_file(file), int(highest)


def parse_arguments(arguments: list[str]) -> tuple[Path, list[tuple[str, Path]], dict[str, tuple[Path, int]]]:
    """Read the command line into the output, the entries in order, and each entry's status check."""
    parser = argparse.ArgumentParser(description="Write an EngineScript site archive from files and pipes.")
    parser.add_argument("output", help="the name of the ZIP to write")
    parser.add_argument("entries", nargs="+", metavar="entry=source", help="an entry's name and its file or pipe")
    parser.add_argument(
        "--status",
        nargs=3,
        action="append",
        default=[],
        metavar=("entry", "file", "highest"),
        help="the file with the exit status of the command that feeds an entry, and the highest status accepted",
    )
    options = parser.parse_args(arguments)
    try:
        output = local_file(options.output)
        entries = [read_entry(entry) for entry in options.entries]
        checks = [read_status(*status) for status in options.status]
    except ValueError as error:
        parser.error(str(error))
    return output, entries, {name: (file, highest) for name, file, highest in checks}


def add_folder(archive: zipfile.ZipFile, name: str, written: set[str]) -> None:
    """Write a folder's entry, once, readable by its owner only."""
    if name in written:
        return
    info = zipfile.ZipInfo(name, date_time=time.localtime()[:6])
    info.external_attr = ((stat.S_IFDIR | 0o700) << UNIX_MODE_SHIFT) | MSDOS_FOLDER
    archive.writestr(info, b"")
    written.add(name)


def add_entry(archive: zipfile.ZipFile, name: str, source: Path) -> None:
    """Copy a file or a pipe into a stored entry, readable by its owner only."""
    info = zipfile.ZipInfo(name, date_time=time.localtime()[:6])
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = (stat.S_IFREG | 0o600) << UNIX_MODE_SHIFT
    # force_zip64: a pipe's size is not known until it ends, and it may pass 4 GB
    with source.open("rb") as reader, archive.open(info, "w", force_zip64=True) as writer:
        shutil.copyfileobj(reader, writer, COPY_CHUNK_BYTES)


def check_status(name: str, status_file: Path, highest: int) -> None:
    """Raise SourceFailedError unless the command that fed an entry left an accepted status."""
    try:
        status = int(status_file.read_text(encoding="ascii").strip())
    except (OSError, ValueError) as error:
        raise SourceFailedError(f"{name}: the command that feeds it left no exit status ({error})") from error
    if status > highest:
        raise SourceFailedError(f"{name}: the command that feeds it ended with status {status}")


def write_archive(output: Path, entries: list[tuple[str, Path]], statuses: dict[str, tuple[Path, int]]) -> None:
    """Write every entry, in order, checking each feeding command once its entry is read."""
    folders: set[str] = set()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for name, source in entries:
            if "/" in name:
                add_folder(archive, name.rsplit("/", 1)[0] + "/", folders)
            add_entry(archive, name, source)
            if name in statuses:
                check_status(name, *statuses[name])


def main(arguments: list[str]) -> int:
    """Write the archive; on failure remove what was written and say why."""
    output, entries, statuses = parse_arguments(arguments)
    try:
        write_archive(output, entries, statuses)
    except SourceFailedError as error:
        print(f"site-archive-zip: {error}", file=sys.stderr)
        output.unlink(missing_ok=True)
        return EXIT_SOURCE_FAILED
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        print(f"site-archive-zip: {error}", file=sys.stderr)
        output.unlink(missing_ok=True)
        return EXIT_IO_ERROR
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
