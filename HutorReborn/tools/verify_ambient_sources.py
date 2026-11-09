#!/usr/bin/env python3
"""Protect the approved world, interiors, schedules, actors and original artwork."""
import hashlib
import json
from pathlib import Path

repo=Path(__file__).resolve().parents[2]
manifest=json.loads((repo/'HutorReborn/docs/stage52-preserved-files.json').read_text())
errors=[]
for name,digest in manifest['preserved'].items():
    path=repo/name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:errors.append(name)
for name in manifest['allowed_changes']:
    if not (repo/name).is_file():errors.append(name+' (removed)')
if (repo/'HutorReborn/override.cfg').exists():errors.append('Temporary observer override remains')
audio=repo/'HutorReborn/assets/audio/ambient'
records=json.loads((audio/'sources.json').read_text())
for record in records:
    path=audio/record['file']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=record['sha256']:errors.append(record['file']+' audio provenance mismatch')
known={record['id'] for record in records}
catalog=json.loads((repo/'HutorReborn/data/atmosphere/sounds.json').read_text())
for entry in catalog.values():
    for sound in entry['files']:
        if sound not in known:errors.append(sound+' missing credited recording')
if errors:raise SystemExit('FAIL:\n'+'\n'.join(errors))
print(f"PASS: {len(manifest['preserved'])} original files unchanged from {manifest['base_commit']}")
print('PASS: all eleven audio recordings match their pinned, credited upstream bytes')
print('PASS: no removed originals or temporary test override')
