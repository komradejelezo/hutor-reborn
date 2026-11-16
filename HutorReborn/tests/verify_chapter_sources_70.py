#!/usr/bin/env python3
"""Scope/integrity guard against merged PR #34; no original art or map rewrites."""
from pathlib import Path
import ast
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = '6781b26'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True)


expected = {
    'HutorReborn/project.godot', 'HutorReborn/scripts/world.gd',
    'HutorReborn/scripts/npc/npc_interaction.gd',
    'HutorReborn/scripts/life/village_life.gd', 'HutorReborn/scripts/menu/main_menu.gd'
}
modified = set(git('diff', '--name-only', '--diff-filter=M', BASE).splitlines())
assert modified == expected, modified
assert not git('diff', '--name-only', '--diff-filter=D', BASE).strip()
print('PASS: only five existing integration files changed; nothing deleted')
for scope in ['HutorReborn/assets', 'HutorReborn/scenes/world', 'HutorReborn/scenes/interiors',
              'HutorReborn/data/life', 'HutorReborn/dialogues', 'HutorReborn/scripts/combat',
              'HutorReborn/scenes/combat', 'HutorReborn/scripts/dialogue']:
    assert not git('diff', BASE, '--', scope), scope
print('PASS: approved models, village, six rooms, schedules, legacy dialogue and combat arena unchanged')
project = ROOT / 'HutorReborn'
assert not (project / 'override.cfg').exists()
assert not (project / 'tools/__pycache__').exists()
for p in (project / 'scripts/chapter').glob('*.gd'):
    s = p.read_text()
    assert not re.search(r'^(<<<<<<< |=======|>>>>>>> )', s, re.M), p
    names = re.findall(r'^(?:static )?func (\w+)\(', s, re.M)
    assert len(names) == len(set(names)), p
print('PASS: no observer override, Python cache, conflict markers or duplicate chapter functions')
for p in (project / 'tools').glob('*70.py'):
    ast.parse(p.read_text(), filename=str(p))
for name in ['logging_camp', 'abandoned']:
    text = (project / 'scenes/chapter' / (name + '.tscn')).read_text()
    for node in ['Actors', 'Hans', 'Residents', 'Navigation', 'Entry', 'Exit', 'Atmosphere', 'HUD']:
        assert f'[node name="{node}"' in text, (name, node)
    assert '[node name="Floor"' in text or '[node name="Ground"' in text
    assert 'parent="Actors/Hans"' not in text, 'Inherited Hans nodes must not be duplicated'
    for path in re.findall(r'path="(res://[^"]+)"', text):
        assert (project / path.removeprefix('res://')).is_file(), path
print('PASS: both complete editable locations reference existing assets, original Hans and valid resource paths')
save = (project / 'scripts/chapter/chapter_save.gd').read_text()
assert 'chapter_i/' in save and '"test/" if test else "normal/"' in save
assert 'HASH_SHA256' in save and 'bytes_to_var(bytes)' in save
print('PASS: separate save namespaces, integrity checksum and object-free deserialization')
print('RESULT: 5 chapter source/integrity groups passed')
