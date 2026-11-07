#!/usr/bin/env python3
"""Verify Stage 4.9.1 keeps the approved world, interiors, art and NPC systems."""
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
manifest = json.loads((repo / 'HutorReborn/docs/stage491-preserved-files.json').read_text())
failures = []
for name, digest in manifest['preserved'].items():
    path = repo / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        failures.append(name)
for name in manifest['allowed_changes']:
    if not (repo / name).is_file():
        failures.append(name + ' (removed)')
if failures:
    raise SystemExit('Preservation failed:\n' + '\n'.join(failures))
print(f"PASS: {len(manifest['preserved'])} original files unchanged from {manifest['base_commit']}")
print(f"PASS: {len(manifest['allowed_changes'])} explicitly allowed files still exist")
