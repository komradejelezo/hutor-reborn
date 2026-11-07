#!/usr/bin/env python3
"""Verify that Stage 4.9.3 preserves every original file except its two fixes."""
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
manifest = json.loads((repo / 'HutorReborn/docs/stage493-preserved-files.json').read_text())
failures = []
for name, digest in manifest['preserved'].items():
    path = repo / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        failures.append(name)
for name in manifest['allowed_changes']:
    if not (repo / name).is_file():
        failures.append(name + ' (removed)')
if (repo / 'HutorReborn/override.cfg').exists():
    failures.append('Temporary observer override.cfg remains in project')
if failures:
    raise SystemExit('Preservation failed:\n' + '\n'.join(failures))
print(f"PASS: {len(manifest['preserved'])} original files unchanged from {manifest['base_commit']}")
print(f"PASS: {len(manifest['allowed_changes'])} allowed original files still exist; no test override")
