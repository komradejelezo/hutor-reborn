"""Audit original files, saved map nodes and exact Nearest source-pixel provenance.

Run after review_residents.gd: python3 tests/verify_resident_sources.py <audit.json>.
Pillow/numpy are authoring dependencies, never needed to play the project.
"""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image

P = Path(__file__).resolve().parents[1]
baseline = json.loads((P / 'docs/stage43-preserved-files.json').read_text(encoding='utf-8'))
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


def digest(value):
    return hashlib.sha256(value).hexdigest()


for name, expected in baseline['files'].items():
    check(digest((P / name).read_bytes()) == expected, 'Existing file changed: ' + name)
scene = (P / 'scenes/world/krivaya_sosna/krivaya_sosna.tscn').read_text(encoding='utf-8')
reference = '[ext_resource type="PackedScene" path="res://scenes/npc/residents.tscn" id="stage43_residents"]\n\n'
instance = '[node name="Residents" parent="Actors" instance=ExtResource("stage43_residents")]\n\n'
check(scene.count(reference) == scene.count(instance) == 1, 'One population instance')
check(digest(scene.replace(reference, '').replace(instance, '').encode()) == baseline['map_sha256'], 'Map bytes preserved except population instance')
navigation = (P / 'assets/npc/stage43/navigation.tres').read_text(encoding='utf-8')
check(baseline['map_sha256'] in navigation, 'Navigation matches approved static world')
if len(sys.argv) > 1:
    state = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))['scene_state']
    for node, expected in baseline['nodes'].items():
        check(node in state, 'Old node missing: ' + node)
        actual = json.dumps(state[node], sort_keys=True, separators=(',', ':')).encode()
        check(digest(actual) == expected, 'Old node changed: ' + node)
    check(all(node.startswith('Actors/Residents') for node in state.keys() - baseline['nodes'].keys()), 'Only resident nodes added')

manifest = json.loads((P / 'assets/npc/stage43/sprite_manifest.json').read_text(encoding='utf-8'))
check(len(manifest['residents']) == 9, 'Nine sprite sets')
total_pixels = 0
atlas_hashes = set()
frames_checked = 0
for npc, data in manifest['residents'].items():
    atlas_path = P / 'assets/npc/stage43' / npc / 'atlas.png'
    atlas = Image.open(atlas_path).convert('RGBA')
    total_pixels += atlas.width * atlas.height
    atlas_hashes.add(digest(atlas_path.read_bytes()))
    for source, expected in data['sources'].items():
        check(digest((P / 'assets/npc/stage2' / source).read_bytes()) == expected, 'Source SHA: ' + source)
    frames = []
    for i, frame in enumerate(data['frames']):
        source = Image.open(P / 'assets/npc/stage2' / frame['source']).convert('RGBA')
        crop = source.crop(frame['box']).resize(tuple(frame['resized']), Image.Resampling.NEAREST)
        reconstructed = Image.new('RGBA', (96, 96))
        reconstructed.paste(crop, tuple(frame['offset']))
        actual = atlas.crop((i % 8 * 96, i // 8 * 96, i % 8 * 96 + 96, i // 8 * 96 + 96))
        a, b = np.array(actual), np.array(reconstructed)
        visible = a[:, :, 3] > 0
        check(np.array_equal(a[:, :, :3][visible], b[:, :, :3][visible]), npc + ' visible pixels from original Nearest crop')
        check(np.all(a[:, :, 3] <= b[:, :, 3]), npc + ' alpha cleanup cannot make transparent pixels opaque')
        check(abs(frame['resized'][0] - (frame['box'][2] - frame['box'][0]) * frame['scale']) <= .51, npc + ' uniform x scale')
        check(abs(frame['resized'][1] - (frame['box'][3] - frame['box'][1]) * frame['scale']) <= .51, npc + ' uniform y scale')
        frames.append(digest(actual.tobytes()))
        frames_checked += 1
    for direction in ('down', 'up', 'right'):
        check(len({frames[i] for i in data['clips']['walk_' + direction]}) >= 2, npc + ' genuine distinct walk frames')
        check(len(data['clips']['idle_' + direction]) == 1, npc + ' explicit static idle fallback')
    check(data['clips']['walk_left'] == data['clips']['walk_right'], npc + ' mirrored left source')
    check(len(data['missing_art']) == 8, npc + ' missing art explicitly listed')
    if npc == 'woodcutter_son':
        check(all(f['source'].startswith('Сын дровосека/') for f in data['frames']), 'Real child artwork')
        check(data['height'] < 40, 'Own child proportions')
check(len(atlas_hashes) == 9, 'Nine distinct character atlases')
print(f'PASS: {checks} source/preservation checks; {len(baseline["files"])} original files; {len(baseline["nodes"])} original nodes; {frames_checked} original frames; {total_pixels * 4 / 1048576:.2f} MiB uncompressed NPC atlases')
