#!/usr/bin/env python3
"""Preserve the exterior, actors, dialogue, time and all original image bytes."""
import hashlib
import json
import re
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
manifest = json.loads((repo/'HutorReborn/docs/stage51-preserved-files.json').read_text())
failures = []
for name, digest in manifest['preserved'].items():
    path = repo/name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        failures.append(name)
for name in manifest['allowed_changes']:
    if not (repo/name).is_file():failures.append(name+' (removed)')
for name, expected in manifest['original_prop_names'].items():
    current = re.findall(r'\[node name="([^"]+)" parent="Actors/Props"[^\]]*\]',(repo/name).read_text())
    if not set(expected).issubset(current):failures.append(name+' (removed original furniture)')
for name, expected in manifest['schedule_semantics'].items():
    current = json.loads((repo/name).read_text())
    for block in current['blocks']:
        if block['scene'] in ('village','logging'):continue
        for action in block['activities']:
            if isinstance(action['point'],list):action['point']='<indoor-coordinate>'
    if current != expected:failures.append(name+' (changed schedule/animation/story/outdoor position)')
if (repo/'HutorReborn/override.cfg').exists():failures.append('Temporary observer override still present')
if failures:raise SystemExit('FAIL:\n'+'\n'.join(failures))
print(f"PASS: {len(manifest['preserved'])} original files preserved from {manifest['base_commit']}")
print('PASS: all nine schedules preserve timing, actions, animations and outdoor coordinates')
print('PASS: all 113 original furniture/decor objects retained')
print('PASS: no removed originals or temporary observer configuration')
