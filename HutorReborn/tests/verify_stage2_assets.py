"""Prove original bytes, retained source RGB and preservation of Hans/legacy resources.
Requires Pillow and numpy. Run from any directory; no Godot/Git runtime dependency.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib
P=Path(__file__).resolve().parents[1]
catalog=json.loads((P/'assets/stage2_catalog.json').read_text())
lookup={r['file']:P/r['project_path'] for r in catalog}
for row in catalog:
    path=P/row['project_path']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'],str(path)
    with Image.open(path) as image:
        assert list(image.size)==row['size'] and image.mode==row['mode']
base=P/'assets/environment/krivaya_sosna'
manifest=json.loads((base/'extraction.json').read_text())
for row in manifest['objects']:
    expected=np.array(Image.open(lookup[row['source']]).convert('RGBA').crop(row['box']))
    actual=np.array(Image.open(base/'objects'/(row['name']+'.png')))
    assert actual.shape==expected.shape
    assert np.array_equal(actual[:,:,:3],expected[:,:,:3]),row['name']
    if row['mode']=='rgba':assert np.array_equal(actual,expected),row['name']
    assert np.any(actual[:,:,3]>0),row['name']
    assert row['scale']>0
atlas=Image.open(base/'terrain.png')
for row in manifest['terrain']:
    x,y=row['atlas_cell']
    tile=atlas.crop((x*32,y*32,x*32+32,y*32+32)).convert('RGB')
    expected=Image.open(lookup[row['source']]).crop(row['box']).convert('RGB')
    assert tile.tobytes()==expected.tobytes(),row
edges=Image.open(base/'path_edges.png')
road=Image.open(lookup['Тайл дороги.png'])
for index in range(128):
    v=index%8;x=37+v%4*32;y=127+v//4*32
    actual=edges.crop((index%16*32,index//16*32,index%16*32+32,index//16*32+32)).convert('RGB')
    assert actual.tobytes()==road.crop((x,y,x+32,y+32)).convert('RGB').tobytes()
preserved=json.loads((P/'docs/stage2-preserved-files.json').read_text())
for name,digest in preserved['files'].items():
    assert hashlib.sha256((P/name).read_bytes()).hexdigest()==digest,name
print(f"PASS: {len(catalog)} original images; {len(manifest['objects'])} object crops; "
      f"{len(manifest['terrain'])} terrain cells; 128 road masks; "
      f"{len(preserved['files'])} preserved Hans/legacy files.")
