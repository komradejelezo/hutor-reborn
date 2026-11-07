"""Verify frozen village/Hans/art files and exact source pixels of new modules."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

P = Path(__file__).resolve().parents[1]
baseline = json.loads((P/'docs/stage44-preserved-files.json').read_text(encoding='utf-8'))
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


for file, sha in baseline['files'].items():
    check(hashlib.sha256((P/file).read_bytes()).hexdigest() == sha, 'Existing file changed: '+file)
folder = P/'assets/interiors/stage44'
records = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
provenance = np.load(folder/'floor_provenance.npz')
pixels = 0
for record in records:
    source_path = P/record['source']
    check(hashlib.sha256(source_path.read_bytes()).hexdigest() == record['sha256'], 'Original source SHA: '+record['source'])
    source = np.array(Image.open(source_path).convert('RGB'))
    prepared = np.array(Image.open(folder/(record['name']+'.png')).convert('RGBA'))
    check(tuple(prepared.shape[1::-1]) == tuple(record['size']), 'Native dimensions: '+record['name'])
    check(set(np.unique(prepared[:,:,3])).issubset({0,255}), 'Binary pixel alpha: '+record['name'])
    if record['name'].startswith('floor_atlas_'):
        room = record['name'].removeprefix('floor_atlas_')
        coords = provenance[room]
        expected = source[coords//source.shape[1], coords%source.shape[1]]
        check(np.array_equal(prepared[:,:,:3], expected), 'Every floor pixel comes from its declared original coordinate: '+room)
    else:
        x0,y0,x1,y1 = record['box']
        check(np.array_equal(prepared[:,:,:3], source[y0:y1,x0:x1]), 'Unpainted native crop: '+record['name'])
    pixels += prepared.shape[0]*prepared.shape[1]
check(set(provenance.files) == {'inn','elder','herbalist'}, 'Exactly three source-pixel floor quilts')
for room in ['inn','elder','herbalist']:
    scene = (P/'scenes/interiors'/f'{room}.tscn').read_text(encoding='utf-8')
    check('[node name="Floor" type="TileMapLayer"' in scene, 'Saved editable floor: '+room)
    check('[node name="Walls" type="TileMapLayer"' in scene, 'Saved editable walls: '+room)
    check('res://assets/characters/hans_frames.tres' not in scene, 'Hans remains a proper scene instance, no flattened replacement children')
    for line in scene.splitlines():
        if line.startswith('[node name="Art"'):
            check('type=' not in line, 'Property override preserves inherited prop ownership')
print(f'PASS: {checks} source/preservation checks; {len(baseline["files"])} original files unchanged; {len(records)} derived modules/atlases; {pixels} native source pixels')
