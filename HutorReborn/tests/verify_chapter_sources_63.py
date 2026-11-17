#!/usr/bin/env python3
"""Stage-specific integrity guard; the 7.0 guard intentionally pins its older scope."""
import ast
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / 'HutorReborn'
BASE = '5222c33'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True)


expected = {
    'HutorReborn/dialogues/residents/old_man.json',
    'HutorReborn/scenes/interiors/inn.tscn',
    *('HutorReborn/scripts/chapter/' + name + '.gd'
      for name in ['chapter_actions', 'chapter_content', 'chapter_director', 'chapter_world']),
    'HutorReborn/tests/verify_chapter_flow_70.gd',
    'HutorReborn/tests/verify_stage51.gd',
}
assert set(git('diff', '--name-only', '--diff-filter=M', BASE).splitlines()) == expected
assert not git('diff', '--name-only', '--diff-filter=D', BASE).strip()
print('PASS: only the six required production files and two regression fixtures changed; no deletions')
for scope in ['assets', 'scenes/player', 'scenes/npc', 'scenes/world', 'data',
              'scripts/player.gd', 'scripts/npc', 'scripts/life', 'scripts/interiors',
              'scripts/dialogue', 'scripts/combat', 'scenes/combat', 'project.godot',
              'scripts/chapter/chapter_save.gd']:
    assert not git('diff', BASE, '--', 'HutorReborn/' + scope), scope
for room in ['elder', 'herbalist', 'woodcutter', 'old_man', 'storehouse']:
    assert not git('diff', BASE, '--', f'HutorReborn/scenes/interiors/{room}.tscn')
print('PASS: original graphics, Hans, all NPCs/schedules, five rooms, village, travel, dialogue engine and combat preserved')
for p in [*PROJECT.glob('scripts/chapter/*.gd'), *PROJECT.glob('tests/*63.gd'), *PROJECT.glob('tools/*63.gd')]:
    text = p.read_text()
    assert not re.search(r'^(<<<<<<< |=======|>>>>>>> )', text, re.M), p
    names = re.findall(r'^(?:static )?func (\w+)\(', text, re.M)
    assert len(names) == len(set(names)), p
assert not (PROJECT / 'override.cfg').exists()
assert not (PROJECT / '.base').exists()
assert not (PROJECT / 'tools/__pycache__').exists()
for path in re.findall(r'path="(res://[^"]+)"', (PROJECT / 'scenes/interiors/inn.tscn').read_text()):
    assert (PROJECT / path.removeprefix('res://')).is_file(), path
ast.parse(Path(__file__).read_text())
print('PASS: no fixture override, caches, conflict markers, duplicate functions or missing inn resources')
print('RESULT: 3 source/integrity groups passed')
