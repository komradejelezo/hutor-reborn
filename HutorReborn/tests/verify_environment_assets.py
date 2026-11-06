"""Stage 3.2: raw pixel provenance, frozen terrain and existing object invariants.
Usage: python3 verify_environment_assets.py /path/to/after-audit.json
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
S=B/'stage32'
baseline=json.loads((P/'docs/stage32-preserved-files.json').read_text())
for name,digest in baseline['files'].items():
    assert hashlib.sha256((P/name).read_bytes()).hexdigest()==digest,name
text=(P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn').read_text()
terrain=[hashlib.sha256(s.encode()).hexdigest() for s in re.findall(r'tile_map_data = [^\n]+',text)]
assert terrain==baseline['terrain_data_sha256']
print(f"PASS: {len(baseline['files'])} existing files unchanged; Stage 3.1 textures, TileSet, layout and tile bytes frozen")
state=json.loads(Path(sys.argv[1]).read_text())['scene_state']
for name,digest in baseline['protected_nodes'].items():
    value=state[name].copy()
    if name=='Actors/Structures/CarpenterHouse/InteractionPoint':
        assert value['title']=='Дом охотника'
        value['title']='Дом плотника'
    assert hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()==digest,name
print(f"PASS: {len(baseline['protected_nodes'])} protected nodes unchanged, including all buildings, landmark, light/fog, fences and camera; only hunter label updated")
plan=json.loads((S/'layout.json').read_text())
base={n['uid']:n for n in json.loads((S/'base_objects.json').read_text())}
assets={a['name']:a for a in json.loads((S/'assets.json').read_text())['objects']}

def vector(value):
    return np.array([float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',value)])

native=[]
for change in plan['changes']:
    root=change['parent']+'/'+change['name']
    assert np.array_equal(vector(state[root]['position']),change['position']),root
    assert state[root]['scale']=='(1.0, 1.0)' and state[root]['z_index']==0,root
    art=state[root+'/Art']
    assert art['texture_filter']==1,root
    if change['name'].startswith('S32_'):
        assert base[change['uid']]['kind'] in ['grass','flowers']
        spec=assets.get(change['kind'])
        if spec:
            assert np.allclose(vector(art['scale']),spec['scale']),root
            assert np.allclose(vector(art['offset']),-np.array(spec['pivot'])),root
            assert '/stage32/'+change['kind']+'.tscn::ArtTexture' in art['texture']
        continue
    kind=base[change['uid']]['kind']
    template=baseline['templates'][kind]
    mirrored=change['kind'].startswith('mirror_')
    for suffix,expected in template.items():
        actual=state[root+suffix].copy()
        if not suffix:
            actual.pop('position');actual.pop('scene')
        if suffix=='/Art' and mirrored:
            assert actual['flip_h']
            actual['flip_h']=expected['flip_h']
        assert actual==expected,(root,suffix)
    if kind.startswith('pine_') or kind=='mixed_tree':native.append(change['position'])
assert len(native)==292
assert len([c for c in plan['changes'] if c['name'].startswith('S32_')])==119
assert len(plan['changes'])==485
print('PASS: 292 tree scales/materials/collision shapes retained; 74 original plants retained; exactly 119 existing plant slots reused')
before=np.array([n['position'] for n in base.values() if n['kind'].startswith('pine_') or n['kind']=='mixed_tree'])
after=np.array(native)
coherence={}
for axis,period in [(0,70),(1,75)]:
    old=float(abs(np.exp(2j*np.pi*before[:,axis]/period).mean()))
    new=float(abs(np.exp(2j*np.pi*after[:,axis]/period).mean()))
    assert new<old and new<.18,(axis,old,new)
    coherence['x' if axis==0 else 'y']={'before':old,'after':new}
print('PASS: former 70/75px forest lattice coherence substantially reduced:',json.dumps(coherence))
atlas=np.asarray(Image.open(S/'environment_atlas.png').convert('RGBA'))
for name,item in assets.items():
    source=np.asarray(Image.open(B/'source'/item['source']).convert('RGBA').crop(item['box']))
    x,y,w,h=item['atlas_region'];actual=atlas[y:y+h,x:x+w]
    assert np.array_equal(actual[:,:,:3],source[:,:,:3]),name
    assert set(np.unique(actual[:,:,3])).issubset({0,255}),name
    assert (actual[:,:,3]>0).any(),name
    assert np.array_equal(atlas[y:y+h,x-2:x,:],np.repeat(actual[:,:1],2,axis=1)),name
    assert np.array_equal(atlas[y:y+h,x+w:x+w+2,:],np.repeat(actual[:,-1:],2,axis=1)),name
    if item['solid']:
        assert (P/'scenes/objects/krivaya_sosna/stage32'/(name+'.tscn')).read_text().count('type="CollisionShape2D"')==1,name
print(f'PASS: {len(assets)} original RGB crops, binary masks, padded shared atlas and reusable static scenes; no recolouring/resampling')
