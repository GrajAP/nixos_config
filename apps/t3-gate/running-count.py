#!/usr/bin/env python3
"""Print how many T3 Code runs are currently 'running' for this user.

Read once from the T3 orchestration projection, read-only, so it is safe to run
while the T3 server has the database open. Prints a single integer and never
fails: a host without T3, or without the projection, is simply not busy.
"""
import os
import sqlite3
from urllib.parse import quote

DB_RELATIVE = os.path.join("userdata", "statev2.sqlite")
RUNNING_SQL = (
    "select count(*) from orchestration_v2_projection_runs where status = 'running'"
)


def db_path():
    home = os.environ.get("T3CODE_HOME") or os.path.join(os.path.expanduser("~"), ".t3")
    return os.path.join(home, DB_RELATIVE)


def running_count():
    path = db_path()
    if not os.path.exists(path):
        return 0
    try:
        con = sqlite3.connect("file:%s?mode=ro" % quote(path), uri=True, timeout=2)
    except sqlite3.Error:
        return 0
    try:
        return int(con.execute(RUNNING_SQL).fetchone()[0])
    except sqlite3.Error:
        return 0
    finally:
        con.close()


def main():
    print(running_count())


if __name__ == "__main__":
    main()
