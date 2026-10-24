#!/usr/bin/env python3
"""Collect already-built browser and game artifacts into an immutable release."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
release = sys.argv[1]
if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]*", release):
    raise SystemExit("Invalid release name")
destination = root / "Ambient/tmp/deploy" / release
if destination.exists():
    raise SystemExit(f"Release already exists: {destination}")
game = root / "wingrivals/build"
web = root / "Ambient/web/www/dist"
if not (game / "lsvr7wpee4biw3sleyscm7har4xzjvoa/server/server_aceclone.wasm").is_file():
    raise SystemExit("Build the game before staging a release")
if not (web / "index.html").is_file():
    raise SystemExit("Build the production browser bundle before staging a release")
shutil.copytree(web, destination / "web")
shutil.copytree(game, destination / "game")
index = destination / "web/index.html"
index.write_text(index.read_text().replace("<title>Ambient</title>", "<title>Wing Rivals</title>"))
for asset in (root / "wingrivals/nginx/html").glob("*.webp"):
    shutil.copy2(asset, destination / "web" / asset.name)
revisions = {}
for name in ("Ambient", "wingrivals"):
    revisions[name] = {
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root / name, text=True).strip(),
        "status": subprocess.check_output(["git", "status", "--short"], cwd=root / name, text=True),
    }
(destination / "release.json").write_text(json.dumps({"release": release, "sources": revisions}, indent=2) + "\n")
with (destination / "SHA256SUMS").open("w") as checksums:
    for path in sorted(destination.rglob("*")):
        if path.is_file() and path.name != "SHA256SUMS":
            checksums.write(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(destination)}\n")
print(destination)
