"""Repair Docker-mounted paths, drop root privileges, and run the command."""

from __future__ import annotations

import os
import pwd
import sys
from pathlib import Path


RUNTIME_USER = "appuser"
WRITABLE_PATHS = (
    Path("/home/appuser/.tradingagents"),
    Path("/home/appuser/app/reports"),
)


def _chown_tree_if_needed(path: Path, uid: int, gid: int) -> None:
    """Give the runtime user ownership of a named volume or bind mount."""
    path.mkdir(parents=True, exist_ok=True)
    stat = path.lstat()
    if stat.st_uid == uid and stat.st_gid == gid:
        return

    for root, directories, files in os.walk(path, topdown=False, followlinks=False):
        for name in (*directories, *files):
            os.lchown(Path(root) / name, uid, gid)
        os.lchown(root, uid, gid)


def _drop_privileges(user: pwd.struct_passwd) -> None:
    os.initgroups(user.pw_name, user.pw_gid)
    os.setgid(user.pw_gid)
    os.setuid(user.pw_uid)
    os.environ.update(HOME=user.pw_dir, USER=user.pw_name, LOGNAME=user.pw_name)


def main() -> None:
    user = pwd.getpwnam(RUNTIME_USER)
    if os.geteuid() == 0:
        for path in WRITABLE_PATHS:
            _chown_tree_if_needed(path, user.pw_uid, user.pw_gid)
        _drop_privileges(user)

    command = sys.argv[1:] or ["tradingagents"]
    os.execvp(command[0], command)


if __name__ == "__main__":
    main()
