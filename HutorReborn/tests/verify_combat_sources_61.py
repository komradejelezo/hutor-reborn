#!/usr/bin/env python3
"""Guard Stage 6.1 isolation against the reviewed main revision (PR #33)."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='f5221a2')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    repo = project.parent

    def git(*arguments):
        return subprocess.check_output(['git', '-C', str(repo), *arguments])

    modified = git('diff', '--name-only', '--diff-filter=MD', args.base).decode().splitlines()
    assert modified == ['HutorReborn/project.godot'], modified
    original = git('show', args.base + ':HutorReborn/project.godot')
    expected = original.replace(
        b'run/main_scene="res://scenes/world/krivaya_sosna/krivaya_sosna.tscn"',
        b'run/main_scene="res://scenes/menu/MainMenu.tscn"'
    )
    assert (project / 'project.godot').read_bytes() == expected
    print('PASS: every pre-existing file identical to base except exact startup scene line')
    assert not (project / 'override.cfg').exists()
    assert not (project / 'tools/__pycache__').exists()
    print('PASS: no test observer override or Python cache left in project')

    production = list((project / 'scripts/combat').rglob('*.gd')) + list((project / 'scripts/menu').glob('*.gd'))
    forbidden = re.compile(r'VillageLife|DialogueManager|InteriorTravel|user://|FileAccess\.WRITE|FileAccess\.READ_WRITE')
    for path in production:
        source = path.read_text()
        assert not forbidden.search(source), path
        assert not re.search(r'^(<<<<<<< |=======|>>>>>>> )', source, re.M), path
        functions = re.findall(r'^(?:static )?func (\w+)\(', source, re.M)
        assert len(functions) == len(set(functions)), path
    print('PASS: battle/menu never mutate world singletons, saves or existing resources')

    settings = (project / 'project.godot').read_text()
    assert 'textures/canvas_textures/default_texture_filter=0' in settings
    print('PASS: original Nearest filtering retained')
    root = project / 'assets/combat/stage61'
    manifest = json.loads((root / 'manifest.json').read_text())
    for source in manifest['sources'].values():
        assert hashlib.sha256((root / 'source' / source['file']).read_bytes()).hexdigest() == source['sha256']
    for pose in manifest['poses']:
        image = Image.open(root / (pose['kind'] + '.png'))
        assert image.mode == 'RGBA' and image.size == (96, 96)
        histogram = image.getchannel('A').histogram()
        assert sum(histogram[1:255]) == 0
        assert image.getbbox()[3] == 82, (pose['kind'], image.getbbox())
        pixels = image.load()
        assert all(pixels[x, y][:3] == (0, 0, 0) for y in range(96) for x in range(96) if pixels[x, y][3] == 0)
    print('PASS: generated sources intact; poses have binary alpha, clean transparent RGB and common foot anchor')

    config = json.loads((project / 'data/combat/prototype.json').read_text())
    assert len(config['scenarios']) == 6 and len(config['units']) == 7
    assert config['units']['hans']['frames'] == 'res://assets/characters/hans_frames.tres'
    for unit in config['units'].values():
        resource = unit.get('frames', unit.get('image', ''))
        assert (project / resource.removeprefix('res://')).is_file(), resource
    for path in [project / 'tools/prepare_combat_61.py', project / 'tools/native_combat_61.py', project / 'tools/run_combat_native_61.py', Path(__file__)]:
        ast.parse(path.read_text(), filename=str(path))
    print('PASS: six scenario definitions, original approved model references and Python syntax')
    print('RESULT: 6 source integrity/isolation checks passed')


if __name__ == '__main__':
    main()
