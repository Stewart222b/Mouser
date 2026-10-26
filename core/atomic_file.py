"""Temporary files for atomic writes, with bounded name-collision retries."""

import os
import secrets


def create_atomic_temp(*, dir, prefix=".mouser.", suffix=".tmp"):
    """Create a private sibling file; propagate access errors immediately.

    On Windows, tempfile.mkstemp can retry PermissionError thousands of
    times when a directory looks writable but a file policy rejects creates.
    Only an actual filename collision warrants retrying here.
    """
    flags = os.O_RDWR | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    for _ in range(8):
        path = os.path.join(dir, prefix + secrets.token_hex(16) + suffix)
        try:
            return os.open(path, flags, 0o600), path
        except FileExistsError:
            continue
    raise FileExistsError("Could not allocate a unique atomic-write temporary file")
