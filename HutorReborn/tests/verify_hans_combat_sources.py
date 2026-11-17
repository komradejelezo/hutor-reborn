#!/usr/bin/env python3
"""Verify original package bytes, import settings and additive prototype scope."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from zipfile import ZipFile

from PIL import Image


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    repo = project.parent
    assets = project / 'assets/characters/hans_combat_prototype_v1'
    changed = subprocess.check_output(
        ['git', '-C', str(repo), 'diff', '--name-only', '--diff-filter=MD', '66cb79f'], text=True)
    assert not changed.strip(), changed
    print('PASS: all pre-existing files match main 66cb79f; only additive prototype files')
    expected = json.loads((assets / 'source_checksums.json').read_text())
    for name, sha in expected.items():
        assert digest((assets / name).read_bytes()) == sha, name
    if args.archive:
        with ZipFile(args.archive) as archive:
            original = {str(Path(i.filename).relative_to('Hans_Combat_Prototype_v1')): digest(archive.read(i))
                        for i in archive.infolist() if not i.is_dir()}
        assert original == expected
    print(f'PASS: {len(expected)} packaged files retain original SHA256, including README/manifest/previews')
    manifest = json.loads((assets / 'animation_manifest.json').read_text())
    unique = {}
    for kind in ['idle', 'dodge']:
        entry = manifest[kind]
        assert entry['pingpong_order_1_based'] == list(range(1, 13)) + list(range(11, 1, -1))
        hashes = set()
        for i in range(1, 13):
            path = assets / kind / f'{kind}_{i:02}.png'
            with Image.open(path) as im:
                assert im.mode == 'RGBA' and list(im.size) == entry['size']
                alpha = im.getchannel('A').histogram()
                assert alpha[0] and alpha[255] and sum(alpha[1:255])
            hashes.add(digest(path.read_bytes()))
        unique[kind] = len(hashes)
        for path in (assets / kind).glob('*.png.import'):
            source = path.read_text()
            for option in ['compress/mode=0', 'mipmaps/generate=false',
                           'process/fix_alpha_border=false', 'process/premult_alpha=false']:
                assert option in source, (path, option)
    assert unique == {'idle': 7, 'dodge': 12}, unique
    print('PASS: 24 original RGBA frames, correct dimensions/order, lossless import, no alpha cleanup')
    print('KNOWN SOURCE LIMIT: 12 Idle files contain only 7 unique images; retained exactly as supplied')
    for path in (project / 'scripts/combat/prototype').glob('*.gd'):
        source = path.read_text()
        names = re.findall(r'^func (\w+)\(', source, re.M)
        assert len(names) == len(set(names)), path
        assert not re.search(r'^(<<<<<<< |=======|>>>>>>> )', source, re.M), path
    assert not (project / 'override.cfg').exists()
    assert not (project / 'tools/__pycache__').exists()
    print('PASS: no conflict markers, duplicate functions, observer overrides or Python caches')
    print('RESULT: 4 source/integrity groups passed')


if __name__ == '__main__':
    main()
