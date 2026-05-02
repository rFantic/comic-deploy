"""Cookie sync init script — copies Firefox cookies from host bind mount,
applies WAL checkpoint so the main .sqlite file is up-to-date.

Run as a Kubernetes init container before the main app starts.
"""

import shutil
import sqlite3
import os
import sys

SRC_DIR = "/root/.mozilla/firefox/676nh1ee.near"
DST_DIR = "/tmp/cookie-sync"
COOKIE_DB = "cookies.sqlite"


def main():
    src_db = os.path.join(SRC_DIR, COOKIE_DB)
    if not os.path.exists(src_db):
        print(f"Source cookie DB not found: {src_db}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(DST_DIR, exist_ok=True)

    # Copy main DB + WAL + SHM
    for suffix in ("", "-wal", "-shm"):
        src = os.path.join(SRC_DIR, COOKIE_DB + suffix)
        dst = os.path.join(DST_DIR, COOKIE_DB + suffix)
        if os.path.exists(src):
            shutil.copy2(src, dst)

    # Checkpoint WAL into main DB
    dst_db = os.path.join(DST_DIR, COOKIE_DB)
    try:
        conn = sqlite3.connect(dst_db)
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        conn.close()
        print(f"Cookie sync done: {dst_db}")
    except Exception as e:
        print(f"WAL checkpoint failed (non-fatal): {e}", file=sys.stderr)
        sys.exit(0)  # non-fatal, don't block pod start


if __name__ == "__main__":
    main()
