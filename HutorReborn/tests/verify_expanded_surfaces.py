"""Validate source pixels, periodic edges, overlay cells and preserved resources.
Authoring verification only: Python 3, Pillow and numpy; no game dependency.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

P = Path(__file__).resolve().parents[1]
B = P / 'assets/environment/krivaya_sosna'
S = B / 'surfaces'
manifest = json.loads((S / 'manifest.json').read_text())
layout = json.loads((B / 'expanded_layout.json').read_text())
baseline = json.loads((P / 'docs/expanded-preserved-files.json').read_text())
for name, digest in baseline['files'].items():
    assert hashlib.sha256((P / name).read_bytes()).hexdigest() == digest, name
print(f"PASS: {len(baseline['files'])} existing resource/controller files byte-identical")

with np.load(S / 'provenance.npz') as provenance:
    for name, spec in manifest['materials'].items():
        actual = np.asarray(Image.open(S / (name + '.png')).convert('RGB'))
        original = np.asarray(Image.open(B / 'source' / spec['source']).convert('RGB'))
        uv = provenance[name]
        assert actual.shape == (spec['size'], spec['size'], 3), name
        assert np.array_equal(actual, original[uv[:, :, 1], uv[:, :, 0]]), name
        x0, y0, x1, y1 = spec['box']
        assert (uv[:, :, 0] >= x0).all() and (uv[:, :, 0] < x1).all(), name
        assert (uv[:, :, 1] >= y0).all() and (uv[:, :, 1] < y1).all(), name
        assert np.array_equal(actual[0], actual[-1]), name
        assert np.array_equal(actual[:, 0], actual[:, -1]), name
        # Internal atlas boundaries must not introduce abnormal colour jumps.
        a = actual.astype(float)
        dx = np.abs(a[:, 1:] - a[:, :-1]).mean(2)
        dy = np.abs(a[1:] - a[:-1]).mean(2)
        mean = np.r_[dx.ravel(), dy.ravel()].mean()
        ratios = {}
        for step in (32, 128):
            edge = np.r_[dx[:, step-1::step].ravel(), dy[step-1::step].ravel()]
            ratios[step] = round(float(edge.mean() / mean), 3)
            assert ratios[step] < 1.25, (name, step, ratios[step])
        print(f"PASS: {name}: exact source pixels, periodic wrap, boundary contrast {ratios}")

w, h = layout['map_size']
assert manifest['map_size'] == [w, h]
old_w, old_h = layout['previous_size']
assert 1.98 < w*h/(old_w*old_h) < 2.02
overlay = np.asarray(Image.open(S / 'world_overlay.png').convert('RGBA'))
assert overlay.shape == (h, w, 4)
assert set(np.unique(overlay[:, :, 3])).issubset({0, 255})
assert (overlay[overlay[:, :, 3] == 0, :3] == 0).all()
active = np.argwhere(overlay[:, :, 3].reshape(h//32, 32, w//32, 32).max((1, 3)) > 0)
assert active.tolist() == manifest['active_cells']
assert np.asarray(manifest['cell_kinds']).shape == (h//32, w//32)
reconstructed = np.zeros_like(overlay)
for y, x in active:
    reconstructed[y*32:y*32+32, x*32:x*32+32] = overlay[y*32:y*32+32, x*32:x*32+32]
assert np.array_equal(reconstructed, overlay)
print(f"PASS: {w}x{h} continuous overlay; {len(active)} native 32px cells, binary alpha")

original = np.asarray(Image.open(B / 'objects/garden.png').convert('RGBA'))
bed = np.asarray(Image.open(S / 'garden_blended.png').convert('RGBA'))
assert np.array_equal(original[:, :, :3], bed[:, :, :3])
assert (bed[:, :, 3] <= original[:, :, 3]).all()
assert not bed[0, :, 3].any() and not bed[-1, :, 3].any()
assert not bed[:, 0, 3].any() and not bed[:, -1, 3].any()
print('PASS: garden keeps original RGB/proportions and removes rectangular alpha boundary')

brushes = np.asarray(Image.open(S / 'terrain_brushes.png').convert('RGBA'))
assert brushes.shape == (64, 512, 4)
for row, name in enumerate(('road', 'soil')):
    with np.load(S / 'provenance.npz') as provenance:
        uv = provenance['brush_' + name]
    spec = manifest['materials'][name]
    source = np.asarray(Image.open(B / 'source' / spec['source']).convert('RGB'))
    material = source[uv[:, :, 1], uv[:, :, 0]]
    assert np.array_equal(material[0], material[-1])
    assert np.array_equal(material[:, 0], material[:, -1])
    for mask in range(16):
        tile = brushes[row*32:row*32+32, mask*32:mask*32+32]
        assert np.array_equal(tile[:, :, :3], material)
        assert set(np.unique(tile[:, :, 3])).issubset({0, 255})
print('PASS: 32 native terrain brushes retain provenanced source RGB and seamless borders')
