#!/usr/bin/env python3
"""Restore opaque coverage inside supplied contours, without painting RGB.

Only combat derivatives are written. Originals, poses, canvases and pivots stay.
One-pixel exterior antialiasing and open gaps between limbs/staff are retained.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
from prepare_combat_forest_v2 import main as prepare_v2

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'assets/combat/readability'
STRUCT=np.array([[0,1,0],[1,1,1],[0,1,0]],dtype=bool)

def native_body(image):
    # Source sheets contain detached direction captions and a faint backdrop.
    # Keep the authored main component and its one-pixel antialiased edge.
    a=np.array(image).copy();labels,n=ndimage.label(a[:,:,3]>40)
    if n:
        sizes=np.bincount(labels.ravel());sizes[0]=0
        main=labels==int(sizes.argmax());keep=ndimage.binary_dilation(main,structure=STRUCT)
        a[~keep,3]=0
    return Image.fromarray(a)

def restore(image,domain=None):
    a=np.array(image.convert('RGBA')).copy();original=a.copy()
    support=a[:,:,3]>0
    # Seal only one-source-pixel breaks in the supplied outline. Filling then
    # restores black shadow pixels inside the contour, not an external halo.
    silhouette=ndimage.binary_fill_holes(ndimage.binary_closing(support,structure=STRUCT))|support
    core=ndimage.binary_erosion(silhouette,structure=STRUCT)
    if domain is not None:core&=domain
    a[core,3]=255
    assert np.array_equal(a[:,:,:3],original[:,:,:3])
    assert np.all(a[:,:,3]>=original[:,:,3])
    assert np.array_equal(a[~silhouette],original[~silhouette])
    return Image.fromarray(a),{'restored_pixels':int((a[:,:,3]!=original[:,:,3]).sum()),
        'core_pixels':int(core.sum()),'core_nonopaque':int((a[:,:,3][core]!=255).sum()),
        'rgb_changed':False,'size':list(image.size)}

def main():
    # Deterministic baseline includes approved v2 poses and the local paw repair.
    prepare_v2();OUT.mkdir(parents=True,exist_ok=True);audit=[]
    library=json.loads((PROJECT/'assets/combat/forest_v2/library.json').read_text())
    specs={f['path']:f for cs in library.values() for c in cs.values() for f in c['frames']}
    invoke=library['hans']['use_invoke'];first=invoke['frames'][0]
    original=Image.open(PROJECT/'assets/combat/forest_v2'/first['path'])
    a=np.array(original)[:,:,3]>0
    body=ndimage.binary_fill_holes(ndimage.binary_closing(a,structure=STRUCT))|a
    body=ndimage.binary_dilation(body,structure=STRUCT,iterations=3)
    for path in sorted((PROJECT/'assets/combat/forest_v2/prepared').rglob('*.png')):
        original=Image.open(path);relative=str(path.relative_to(PROJECT/'assets/combat/forest_v2'))
        spec=specs.get(relative)
        if path.parent.name=='Attack':
            audit.append({'path':str(path.relative_to(PROJECT)),'restored_pixels':0,'rgb_changed':False,'reason':'RGB attack already has an opaque body; preserve motion trail/magic alpha'})
            continue
        domain=None
        if path.parent.name=='Use_Invoke' and spec:
            dy=round(spec['origin'][1]-first['origin'][1]);domain=ndimage.shift(body,(dy,0),order=0,mode='constant')
        fixed,info=restore(original,domain);fixed.save(path)
        audit.append({'path':str(path.relative_to(PROJECT)),**info})
    for kind,folder in [('herbalist','herbalist5410'),('woodcutter','woodcutter542')]:
        source=PROJECT/'assets/npc'/folder/'game/atlas.png'
        im=Image.open(source).convert('RGBA');pixels=0;factor=3 if kind=='herbalist' else 1
        if factor>1:
            # Same approved source crops/pose order/pivots, sampled directly at
            # combat resolution instead of enlarging the 48px world character.
            manifest=json.loads((source.parents[1]/'manifest.json').read_text())
            cell_size=96*factor;result=Image.new('RGBA',(im.width*factor,im.height*factor))
            for i,record in enumerate(manifest['frames']):
                raw=Image.open(source.parents[1]/'source'/record['source']).convert('RGBA').crop(record['box'])
                ratio=record['scale_uniform']*factor;ox,oy=[v*factor for v in record['offset']]
                cell=raw.transform((cell_size,cell_size),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
                fixed,info=restore(native_body(cell));result.paste(fixed,(i%8*cell_size,i//8*cell_size));pixels+=info['restored_pixels']
        else:
            result=im.copy()
            for y in range(0,im.height,96):
                for x in range(0,im.width,96):
                    fixed,info=restore(im.crop((x,y,x+96,y+96)));result.paste(fixed,(x,y));pixels+=info['restored_pixels']
        dest=OUT/(kind+'_atlas.png');result.save(dest)
        frames=(source.parent/'frames.tres').read_text().replace('res://assets/npc/'+folder+'/game/atlas.png','res://assets/combat/readability/'+kind+'_atlas.png')
        if factor>1:
            import re
            frames=re.sub(r'region = Rect2\((\d+), (\d+), 96, 96\)',lambda m:f'region = Rect2({int(m[1])*factor}, {int(m[2])*factor}, {96*factor}, {96*factor})',frames)
        (OUT/(kind+'_frames.tres')).write_text(frames)
        audit.append({'path':str(dest.relative_to(PROJECT)),'original':str(source.relative_to(PROJECT)),
            'original_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'restored_pixels':pixels,'rgb_changed':False,'size':list(result.size),'source_sampling_factor':factor})
    (OUT/'opacity_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print('Opacity repaired:',len(audit),'combat textures; source RGB and world atlases unchanged')

if __name__=='__main__':main()
