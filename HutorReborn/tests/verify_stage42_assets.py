"""Preserve approved files/nodes and prove all new visible pixels' provenance.
Usage: python3 verify_stage42_assets.py /path/to/after-audit.json
"""
from pathlib import Path
import hashlib
import json
import re
import sys
import numpy as np
from PIL import Image

P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'stage42'
baseline=json.loads((P/'docs/stage42-preserved-files.json').read_text())
for name,digest in baseline['files'].items():
 assert hashlib.sha256((P/name).read_bytes()).hexdigest()==digest,name
print('PASS:',len(baseline['files']),'approved files unchanged, including all original art, Hans, dialogue code/data/UI, shaders and old terrain')
scene=(P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn').read_text()
assert [hashlib.sha256(t.encode()).hexdigest() for t in re.findall(r'tile_map_data = [^\n]+',scene)]==baseline['tile_data']
print('PASS: both original serialized TileMapLayer arrays byte-identical')
if len(sys.argv)>1:
 state=json.loads(Path(sys.argv[1]).read_text())['scene_state']
 for key,digest in baseline['nodes'].items():
  normalized={k:v for k,v in state[key].items() if k not in baseline['allowed_node_fields'].get(key,[])}
  assert hashlib.sha256(json.dumps(normalized,sort_keys=True,separators=(',',':')).encode()).hexdigest()==digest,key
 print('PASS:',len(baseline['nodes']),'existing node records preserved with explicit role/placement/bounds field allowances')
 assert sum(v['class']=='CharacterBody2D' for v in state.values())==1
 assert sum(v['class']=='PointLight2D' for v in state.values())==20
 for path,v in state.items():
  if path.startswith('Actors/Structures/AbandonedHouse'):assert v['class']!='PointLight2D'
 assert 'hide_rack' not in state[baseline['repurposed_branch']]['scene']
 print('PASS: one player, three additional inn lights, no abandoned light; hunter rack repurposed')

assets=json.loads((OUT/'assets.json').read_text())
for item in assets:
 original=np.asarray(Image.open(B/'source'/item['source']).convert('RGB').crop(item['box']))
 derived=np.asarray(Image.open(OUT/(item['name']+'.png')).convert('RGBA'))
 assert derived.shape[:2]==original.shape[:2] and np.array_equal(derived[:,:,:3],original),item['name']
 assert set(np.unique(derived[:,:,3]))=={0,255},item['name']
print('PASS: six exterior modules and one medicinal soil bed preserve exact original RGB, dimensions and binary transparency')
plan=json.loads((OUT/'layout.json').read_text())
sources=[np.asarray(Image.open(B/'source'/s).convert('RGB')) for s in plan['source_sheets']]
old_overlay=np.asarray(Image.open(B/'surface_polish/world_overlay.png').convert('RGBA'))
with np.load(OUT/'surface_provenance.npz') as provenance:
 for name,cells in [('extension_ground','ground_cells'),('new_paths','path_cells')]:
  rgba=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'));uv=provenance[name]
  visible=rgba[:,:,3]>0
  assert np.all(uv[visible]!=0),name+' missing provenance'
  sheet=(uv>>22)-1;sx=uv&2047;sy=(uv>>11)&2047
  for index,source in enumerate(sources):
   use=visible&(sheet==index)
   assert np.array_equal(rgba[:,:,:3][use],source[sy[use],sx[use]]),name
  assert np.all((sheet[visible]>=0)&(sheet[visible]<len(sources)))
  assert set(np.unique(rgba[:,:,3])).issubset({0,255})
  if name=='extension_ground':
   expected={(x,y) for y in range(80) for x in range(93) if x>=82 or y>=68}
   assert {(x,y) for x,y,ax,ay in plan[cells]}==expected
  else:
   for x,y,ax,ay in plan[cells]:
    if x<82 and y<68:
     addition=rgba[ay*32:ay*32+32,ax*32:ax*32+32,3]>0
     old=old_overlay[y*32:y*32+32,x*32:x*32+32,3]>0
     assert not (addition&old).any(),(x,y)
print('PASS: all new ground/path pixels trace to original source texels; original visible roads never overpainted')
print('RESULT: Stage 4.2 preservation/art audit passed')
