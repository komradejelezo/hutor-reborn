#!/usr/bin/env python3
"""Apply reviewed garment recipes, never infer silhouettes or paint missing RGB.

Archive originals stay immutable. Each changed RGB pixel is copied exactly from
an adjacent authored frame; all other new coverage uses retained target RGB.
Recipes are frozen after contrast-background review, not selected automatically.
"""
from pathlib import Path
from functools import lru_cache
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage

PROJECT=Path(__file__).resolve().parents[1]
PACK=PROJECT/'assets/combat/forest_v2'
ROOT=PROJECT/'assets/combat/restoration/hans'
STRUCT=np.array([[0,1,0],[1,1,1],[0,1,0]],dtype=bool)

def sha(data):return hashlib.sha256(data).hexdigest()
def read_recipe():
    recipe=json.loads((ROOT/'recipe.json').read_text())
    library_bytes=(PACK/'library.json').read_bytes()
    assert sha(library_bytes)==recipe['library_sha256'],'Animation registration/timing changed; review recipes before applying'
    library=json.loads(library_bytes)['hans']
    for frame in recipe['frames']:
        clip=library[frame['clip']];index=frame['runtime_frame']-1;spec=clip['frames'][index]
        for key in ['path','source','size','origin']:assert frame[key]==spec[key],key+' differs from production registration'
        sources=[f['source'] for f in clip['frames']]
        for patch in frame['patches']:
            if patch.get('donor_source'):
                assert patch['donor_source'] in sources
                assert abs(sources.index(patch['donor_source'])-index)<=2,'Donor is not an adjacent approved gameplay frame'
    return recipe
@lru_cache(maxsize=96)
def source(path,expected_sha):
    p=(PACK/path).resolve()
    assert p.is_relative_to(PACK.resolve()) and p.is_file()
    assert sha(p.read_bytes())==expected_sha,'Original source changed: '+path
    return np.array(Image.open(p).convert('RGBA'))

def baseline(frame):
    # Recreate the existing main preparation exactly, without writing any files.
    # A pixel hash makes future changes to that preparation fail closed.
    from prepare_combat_animation_pack import clean
    from prepare_combat_forest_v2 import close_pinholes
    from repair_combat_opacity import restore
    im,_=clean(PACK/frame['source'],'Hans/'+frame['clip'].capitalize())
    im,_=close_pinholes(im)
    if frame['clip']!='attack':im,_=restore(im)
    if frame['clip']=='dodge':
        raw=source(frame['source'],frame['source_sha256'])
        labels,n=ndimage.label(raw[:,:,:3].max(axis=2)>3)
        if n:
            sizes=np.bincount(labels.ravel());sizes[0]=0
            core=ndimage.binary_erosion(labels==int(sizes.argmax()),structure=STRUCT)
            a=np.array(im);a[core,3]=255;im=Image.fromarray(a)
    array=np.array(im.convert('RGBA'))
    assert sha(array.tobytes())==frame['baseline_pixels_sha256'],'Baseline pixels changed: '+frame['path']
    return array

def polygon_mask(shape,vertices):
    h,w=shape;assert len(vertices)>=3
    assert all(0<=x<w and 0<=y<h for x,y in vertices)
    mask=Image.new('1',(w,h));ImageDraw.Draw(mask).polygon([tuple(v) for v in vertices],fill=1)
    return np.array(mask,dtype=bool)

def translated(array,dx,dy):
    assert isinstance(dx,int) and isinstance(dy,int) and abs(dx)<=12 and abs(dy)<=12
    h,w=array.shape[:2];out=np.zeros_like(array)
    x0=max(0,-dx);x1=min(w,w-dx);y0=max(0,-dy);y1=min(h,h-dy)
    out[y0:y1,x0:x1]=array[y0+dy:y1+dy,x0+dx:x1+dx]
    return out

def restore_frame(frame):
    before=baseline(frame);raw=source(frame['source'],frame['source_sha256'])
    assert list(raw.shape[1::-1])==frame['size'] and raw.shape==before.shape
    result=before.copy();recovered_source=raw.copy();rgb_mask=np.zeros(raw.shape[:2],bool)
    domain_all=np.zeros(raw.shape[:2],bool);trace=[]
    for patch in frame['patches']:
        domain=polygon_mask(raw.shape[:2],patch['polygon']);domain_all|=domain
        # Retained RGB inside a reviewed garment surface: alpha-only recovery.
        own=domain&(raw[:,:,:3].max(axis=2)>0)
        own_runtime=own&(result[:,:,3]<255);own_source=own&(recovered_source[:,:,3]<255)
        result[own_runtime,3]=255;recovered_source[own_source,3]=255
        donor_mask=np.zeros_like(domain)
        if patch.get('donor_source'):
            assert patch['context_mae']<=23 and patch['context_coverage']>=.72
            donor=source(patch['donor_source'],patch['donor_sha256'])
            assert donor.shape==raw.shape
            dx,dy=patch['donor_offset'];mapped=translated(donor,dx,dy)
            x0,y0,x1,y1=patch['context']
            a=raw[y0:y1,x0:x1,:3].astype(float);b=mapped[y0:y1,x0:x1,:3].astype(float)
            known=a.max(axis=2)>15;valid=known&(b.max(axis=2)>15)
            assert valid.sum()>80 and known.sum()>0
            mae=float(np.abs(a-b)[valid].mean());coverage=float(valid.sum()/known.sum())
            assert abs(mae-patch['context_mae'])<.001 and abs(coverage-patch['context_coverage'])<.001,'Donor registration changed: '+frame['path']
            # Do not recolour valid target pixels, opaque black shadows, air
            # outside the reviewed polygon, or previously recovered pixels.
            donor_mask=domain&(raw[:,:,:3].max(axis=2)==0)&(before[:,:,3]<128)&(result[:,:,:3].max(axis=2)==0)&(mapped[:,:,:3].max(axis=2)>8)
            result[donor_mask,:3]=mapped[donor_mask,:3];result[donor_mask,3]=255
            recovered_source[donor_mask,:3]=mapped[donor_mask,:3];recovered_source[donor_mask,3]=255
            rgb_mask|=donor_mask
        trace.append({'region':patch['region'],'own_runtime_alpha_pixels':int(own_runtime.sum()),'own_source_alpha_pixels':int(own_source.sum()),'donor_rgb_pixels':int(donor_mask.sum()),'donor_source':patch.get('donor_source'),'donor_offset':patch.get('donor_offset')})
    changed=np.any(result!=before,axis=2)
    assert np.array_equal(result[~domain_all],before[~domain_all])
    assert np.array_equal(recovered_source[~domain_all],raw[~domain_all])
    assert np.array_equal(result[:,:,:3][~rgb_mask],before[:,:,:3][~rgb_mask])
    assert np.all(result[:,:,3]>=before[:,:,3])
    newly_opaque=(result[:,:,3]>before[:,:,3])
    assert not (newly_opaque&(result[:,:,:3].max(axis=2)==0)).any(),'Never fill a missing colour with black'
    assert not (rgb_mask&(before[:,:,3]>=128)).any(),'Never recolour existing visible shadows'
    return {'frame':frame,'before':before,'prepared':result,'source':recovered_source,'rgb_mask':rgb_mask,'changed':changed,'trace':trace}

def expected_outputs():
    source.cache_clear()
    recipe=read_recipe()
    return {f['path']:restore_frame(f) for f in recipe['frames']}

def apply_reviewed():
    outputs=expected_outputs();audit=[]
    previous=json.loads((ROOT/'provenance.json').read_text())['frames'] if (ROOT/'provenance.json').exists() else []
    prior={row['path']:row for row in previous}
    # Validate all paths before writes; retain user edits instead of clobbering.
    for path,value in outputs.items():
        assert path.startswith('prepared/Hans/')
        current=np.array(Image.open(PACK/path).convert('RGBA'))
        current_hash=sha((PACK/path).read_bytes())
        assert np.array_equal(current,value['before']) or np.array_equal(current,value['prepared']) or current_hash==prior.get(path,{}).get('prepared_sha256'),'Unexpected local edit: '+path
        relative=Path(value['frame']['source']).relative_to('assets/Hans')
        dest=ROOT/'recovered_source'/relative
        if dest.exists():
            assert np.array_equal(np.array(Image.open(dest).convert('RGBA')),value['source']) or sha(dest.read_bytes())==prior.get(path,{}).get('recovered_source_sha256'),'Edited recovered source: '+str(dest)
    for path,value in outputs.items():
        if not value['changed'].any():continue
        relative=Path(value['frame']['source']).relative_to('assets/Hans');dest=ROOT/'recovered_source'/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        recovered=Image.fromarray(value['source'])
        if Image.open(PACK/value['frame']['source']).mode=='RGB':recovered=recovered.convert('RGB')
        recovered.save(dest)
        Image.fromarray(value['prepared']).save(PACK/path)
        audit.append({'path':path,'source':value['frame']['source'],'recovered_source':str(dest.relative_to(PROJECT)),'changed_pixels':int(value['changed'].sum()),'donor_rgb_pixels':int(value['rgb_mask'].sum()),'new_opaque_black_pixels':0,'prepared_sha256':sha((PACK/path).read_bytes()),'recovered_source_sha256':sha(dest.read_bytes()),'trace':value['trace']})
    (ROOT/'provenance.json').write_text(json.dumps({'recipe_version':1,'frames':audit},ensure_ascii=False,indent=2)+'\n')
    return audit

if __name__=='__main__':
    # Standalone use is a read-only check. Regeneration is the existing prep CLI.
    for path,value in expected_outputs().items():
        current=np.array(Image.open(PACK/path).convert('RGBA'))
        assert np.array_equal(current,value['prepared']),path+' is not restored; run tools/repair_combat_opacity.py'
    print('PASS: reviewed Hans recipes match prepared resources')
