#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

SKIP = {"node_modules", ".venv", "venv", "__pycache__", "vendor", "cache", "caches", "logs", "log", "data", "tmp", "dist", "build"}

def git(repo, *args):
    p = subprocess.run(
        ["git", "-c", f"safe.directory={repo}", "-C", str(repo), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=5,
        check=False,
    )
    return p.stdout.strip() if p.returncode == 0 else ""

def sanitize_remote(raw):
    raw = raw.strip()
    if not raw:
        return {"origin_host": None, "origin_path": None, "repository": None}
    host = path = None
    if re.match(r"^[^@\s]+@[^:]+:.+$", raw):
        _, rest = raw.split("@", 1)
        host, path = rest.split(":", 1)
    elif raw.startswith(("http://", "https://", "ssh://", "git://")):
        u = urlsplit(raw)
        host = u.hostname
        path = u.path.lstrip("/")
    if path:
        path = path.removesuffix(".git")
    return {
        "origin_host": host,
        "origin_path": path,
        "repository": f"{host}/{path}" if host and path else None,
    }

def discover(root, max_depth):
    root = Path(root)
    if not root.exists():
        return []
    found = []
    base_depth = len(root.parts)
    for current, dirs, _ in os.walk(root):
        path = Path(current)
        depth = len(path.parts) - base_depth
        dirs[:] = [d for d in dirs if d not in SKIP]
        if ".git" in dirs:
            found.append(path)
            dirs.remove(".git")
        if depth >= max_depth:
            dirs[:] = []
    return found

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", required=True)
    ap.add_argument("--max-depth", type=int, default=5)
    ap.add_argument("roots", nargs="*", default=["/srv", "/opt"])
    args = ap.parse_args()
    result = []
    seen = set()
    for root in args.roots:
        for repo in discover(root, args.max_depth):
            path = str(repo.resolve())
            if path in seen:
                continue
            seen.add(path)
            item = {
                "path": path,
                "branch": git(repo, "symbolic-ref", "--short", "-q", "HEAD") or "DETACHED",
                "head": git(repo, "rev-parse", "HEAD"),
            }
            item.update(sanitize_remote(git(repo, "remote", "get-url", "origin")))
            result.append(item)
    result.sort(key=lambda x: x["path"])
    Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
