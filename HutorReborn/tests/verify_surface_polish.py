"""Run after review_surfaces.gd; audit original pixels and every protected node.
Usage: python3 verify_surface_polish.py /path/to/after-audit.json
"""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image

P = Path(__file__).resolve().parents[1]
B = P/'assets/environment/krivaya_sosna'
S = B/'surface_polish'
manifest = json.loads((S/'manifest.json').read_text())
baseline = json.loads((P/'docs/stage31-preserved-files.json').read_text())
for path,digest in baseline['files'].items():
    assert hashlib.sha256((P/path).read_bytes()).hexdigest()==digest,path
assert hashlib.sha256((B/'expanded_layout.json').read_bytes()).hexdigest()==manifest['layout_sha256']
print(f"PASS: {len(baseline['files'])} protected files, layout, originals and mechanics byte-identical")

audit = json.loads(Path(sys.argv[1]).read_text())
states = audit['scene_state']
assert set(states)==set(baseline['nonterrain_nodes'])
for name,properties in states.items():
    if name=='Actors/Structures/CommonHouse/Art':
        assert properties['texture'].endswith('/surface_polish/common_house_ground.png')
        properties['texture']='res://assets/environment/krivaya_sosna/objects/common_house.png'
    if name.startswith('Ground Objects/Garden') and name.endswith('/Art'):
        assert properties['texture'].endswith('/surface_polish/garden_ground.png')
        properties['texture']='res://assets/environment/krivaya_sosna/objects/garden.png'
    digest=hashlib.sha256(json.dumps(properties,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    assert digest==baseline['nonterrain_nodes'][name],name
print(f"PASS: {len(states)} nonterrain nodes unchanged except five approved ground-mask texture references")

originals = [np.asarray(Image.open(B/'source'/f).convert('RGB')) for f in manifest['source_sheets']]
allowed = [np.zeros(image.shape[:2],bool) for image in originals]
for regions in manifest['regions'].values():
    for sheet,box in regions:
        x0,y0,x1,y1=box
        allowed[sheet][y0:y1,x0:x1]=True
old_manifest=json.loads((B/'surfaces/manifest.json').read_text())
for name in ['soil','moss']:
    info=old_manifest['materials'][name]
    sheet=manifest['source_sheets'].index(info['source'])
    x0,y0,x1,y1=info['box']
    allowed[sheet][y0:y1,x0:x1]=True
allowed[1][718:814,146:226]=True  # Original puddle crop.
images = {name:np.asarray(Image.open(S/('world_'+name+'.png'))) for name in ['ground','overlay']}
w,h = manifest['map_size']
assert [w,h]==[2624,2176]
metrics={}
with np.load(S/'provenance.npz') as origin:
    for name,image in images.items():
        assert image.shape[:2]==(h,w)
        uv=origin[name]
        assert uv.shape==(h,w)
        for y0 in range(0,h,128):
            rgb=image[y0:y0+128,:,:3]
            code=uv[y0:y0+128]
            sheet=code>>22
            sx=code&2047
            sy=(code>>11)&2047
            visible=np.ones(code.shape,bool) if name=='ground' else image[y0:y0+128,:,3]>0
            assert ((sheet[visible]>=1)&(sheet[visible]<=2)).all()
            for i,raw in enumerate(originals):
                mask=visible&(sheet==i+1)
                assert np.array_equal(rgb[mask],raw[sy[mask],sx[mask]]),(name,y0,i)
                assert allowed[i][sy[mask],sx[mask]].all(),(name,'pixel outside approved art interiors')
            assert not code[~visible].any()
        # Transparent RGB is deliberately black, so its edge contrast is not a
        # visible seam. Measure the actual opaque composite drawn by the layers.
        rgb=image[:,:,:3] if name=='ground' else np.where(image[:,:,3:]>0,image[:,:,:3],images['ground'])
        rgb=rgb.astype(np.int16)
        dx=np.abs(rgb[:,1:]-rgb[:,:-1]).mean(2)
        dy=np.abs(rgb[1:]-rgb[:-1]).mean(2)
        ordinary=np.r_[dx.ravel(),dy.ravel()].mean()
        ratios={}
        for step in [32,128,256,512]:
            ratio=float(np.r_[dx[:,step-1::step].ravel(),dy[step-1::step].ravel()].mean()/ordinary)
            assert ratio<1.2,(name,step,ratio)
            ratios[step]=round(ratio,4)
        metrics[name]={'boundary_contrast':ratios}
        print(f'PASS: {name}: exact source RGB inside approved crops; visible boundary contrast {ratios}')

ground=images['ground']
unique=set()
for y in range(0,h,32):
    for x in range(0,w,32):
        unique.add(hashlib.sha256(ground[y:y+32,x:x+32].tobytes()).digest())
assert len(unique)==(w//32)*(h//32)
for shift in [128,256,512]:
    equal=np.all(ground[:,shift:]==ground[:,:-shift],axis=2).mean()
    assert equal<.05,(shift,equal)
    metrics['ground'][f'exact_repeat_{shift}px']=float(equal)
print(f'PASS: {len(unique)} distinct 32px ground cells; no exact 128/256/512px period')

overlay=images['overlay']
assert set(np.unique(overlay[:,:,3]))=={0,255}
assert not overlay[overlay[:,:,3]==0,:3].any()
active=np.argwhere(overlay[:,:,3].reshape(h//32,32,w//32,32).max((1,3))>0)
assert active.tolist()==manifest['active_cells']
print(f'PASS: continuous binary-alpha overlay; {len(active)} native atlas cells')
for name in ['garden','common_house']:
    old=np.asarray(Image.open(B/'objects'/(name+'.png')).convert('RGBA'))
    new=np.asarray(Image.open(S/(name+'_ground.png')).convert('RGBA'))
    assert old.shape==new.shape
    assert np.array_equal(old[:,:,:3],new[:,:,:3])
    assert (new[:,:,3]<=old[:,:,3]).all()
    assert np.count_nonzero(old[:,:,3]!=new[:,:,3])>100
    if name=='common_house':assert np.array_equal(old[:264],new[:264])
    print(f'PASS: {name}: original RGB/proportions retained; alpha changes only; building and steps protected')
expected=json.loads((P/'docs/stage31-tile-audit.json').read_text())['before']
assert audit['display']==expected['display']
assert [r['path'] for r in audit['layers']]==['Ground','Ground Details']
for layer in audit['layers']:
    assert layer['cell_size']=='(32, 32)' and layer['filter']==1
    assert layer['transform']==expected['layers'][0]['transform']
    for source in layer['sources']:
        assert source['region']=='(32, 32)' and source['margins']=='(0, 0)' and source['separation']=='(0, 0)'
        assert source['padding']
print('PASS: same two TileMapLayers, pixel snap, Nearest, margins, separation and native cell dimensions')
print('METRICS:',json.dumps(metrics,sort_keys=True))
