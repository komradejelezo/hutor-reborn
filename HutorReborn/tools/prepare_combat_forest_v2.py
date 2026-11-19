#!/usr/bin/env python3
"""Import supplied v2 poses; preserve RGB, register feet, repair one paw locally.

Originals are immutable. No generated anatomy, interpolation or body stretching.
Dependencies: Pillow, NumPy, SciPy. Run from any directory, then import in Godot.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage, signal
from prepare_combat_animation_pack import clean, feet

ROOT=Path(__file__).resolve().parents[1]/'assets/combat/forest_v2'
MS={'Hans/Idle':155,'Hans/Attack':70,'Hans/Hit':65,'Hans/Dodge':52,
    'Hans/Victory':85,'Hans/Death':75,'Hans/Use_Invoke':70,
    'Wolf/Idle':140,'Wolf/Attack':45,'Wolf/Death':65,
    'Leshy/Idle':175,'Leshy/Attack':65,'Leshy/Death':75}
IMPACT={'Hans/Attack':6,'Wolf/Attack':13,'Leshy/Attack':12,'Hans/Use_Invoke':7}

def register(images,kind):
    """Integer translation from grounded feet, never a scale/breathing warp."""
    base=np.array(images[0]);anchor,bbox=feet(images[0]);x0,y0,x1,y1=bbox
    if kind=='Wolf/Idle':
        patches=[(119,173,152,191),(218,171,247,192),(249,172,276,191)]
    else:
        alpha=base[:,:,3]>128
        ys,xs=np.where(alpha & (np.indices(alpha.shape)[0]>anchor[1]-16))
        patches=[(max(12,int(xs.min())-2),max(4,int(ys.min())),min(base.shape[1]-12,int(xs.max())+3),min(base.shape[0]-4,int(anchor[1])+1))]
    result=[]
    for im in images:
        a=np.array(im);offsets=[]
        for x0,y0,x1,y1 in patches:
            temp=base[y0:y1,x0:x1,3].astype(float)/255
            region=a[y0-4:y1+4,x0-12:x1+12,3].astype(float)/255
            scores=signal.correlate2d(region,temp,mode='valid')-.5*signal.correlate2d(region*region,np.ones_like(temp),mode='valid')
            dy,dx=np.unravel_index(np.argmax(scores),scores.shape)
            offsets.append([int(dx)-12,int(dy)-4])
        result.append(np.median(offsets,axis=0).astype(int).tolist())
    return result

def close_pinholes(im):
    """Only enclosed narrow alpha pinholes; leave larger missing artwork explicit."""
    a=np.array(im).copy();solid=a[:,:,3]>0
    holes=ndimage.binary_fill_holes(solid)&~solid
    labels,n=ndimage.label(holes);count=0
    for k,box in enumerate(ndimage.find_objects(labels),1):
        if box is None:continue
        mask=labels[box]==k
        if mask.sum()<=80 and ndimage.distance_transform_edt(mask).max()<=2:
            view=a[box];view[mask,3]=255;count+=int(mask.sum())
    return Image.fromarray(a),count

def main():
    # Approved v2 task supplies the clip list; LEGACY_* is reference material only.
    kinds=("Hans/Idle Hans/Attack Hans/Hit Hans/Victory Hans/Death "
           "Wolf/Idle Wolf/Attack Wolf/Death Leshy/Idle Leshy/Attack Leshy/Death "
           "Hans/Use_Invoke Hans/Dodge").split()
    entries=[{'animation':kind} for kind in kinds];library={};audit=[]
    for entry in entries:
        kind=entry['animation'];unit,clip=kind.split('/')
        paths=sorted(p for p in (ROOT/'assets'/kind).glob('*.png') if not p.stem.endswith('strip'))
        images=[];infos=[]
        for p in paths:
            im,keyed=clean(p,kind);im,pins=close_pinholes(im)
            images.append(im);infos.append({'source':str(p.relative_to(ROOT)),'size':list(im.size),'source_mode':Image.open(p).mode,'alpha_keyed':keyed,'pinholes_closed':pins})
        shifts=register(images,kind) if clip=='Idle' else [[0,0] for _ in images]
        correction=None
        if kind=='Wolf/Idle':
            # Frame 12: far hind paw has the largest two-neighbour alpha change
            # after removing whole-body drift. Transfer only this grounded patch.
            i=11;previous=10;dx,dy=shifts[i];px,py=shifts[previous]
            rect=(156+dx,169+dy,202+dx,192+dy)
            patch=images[previous].crop((156+px,169+py,202+px,192+py))
            images[i].paste(patch,(rect[0],rect[1]))
            correction={'frame':12,'donor_frame':11,'rect':list(rect),'registered_roi':[156,169,202,192]}
        anchor0,_=feet(images[0]);frames=[]
        for i,(p,im,info) in enumerate(zip(paths,images,infos)):
            a,b=feet(im)
            origin=[anchor0[0]+shifts[i][0],anchor0[1]+shifts[i][1]] if clip=='Idle' else [anchor0[0],a[1]]
            dest=ROOT/'prepared'/unit/clip/p.name;dest.parent.mkdir(parents=True,exist_ok=True);im.save(dest)
            frames.append({**info,'path':str(dest.relative_to(ROOT)),'bbox':list(b),'origin':origin,'registration':shifts[i]})
        order=list(range(1,len(frames)+1))
        if kind=='Hans/Victory':order=list(range(1,9))+[11,12]
        spec={'frames':[frames[i-1] for i in order],'ms':MS[kind],'scale':1.,'loop':clip=='Idle',
              'pingpong':clip=='Idle','hold':clip=='Death','impact':IMPACT.get(kind,0),
              'used_indices':order,'source_count':len(frames),'derived_from':kind,'correction':correction}
        library.setdefault(unit.lower(),{})[clip.lower()]=spec
        audit.append({'animation':kind,'actual_individual_frames':len(frames),'frames':frames,'correction':correction})
    for unit,clips in library.items():
        ref=clips['idle']['frames'][0]['bbox'];height=ref[3]-ref[1]
        for spec in clips.values():
            b=spec['frames'][0]['bbox'];spec['scale']=height/(b[3]-b[1])
        lines=['[gd_resource type="SpriteFrames" format=3]',''];resources=[];animations=[];idx=0
        for clip,spec in clips.items():
            textures=[]
            for f in spec['frames']:
                idx+=1;key='f'+str(idx);textures.append(key);w,h=f['size'];ax,ay=f['origin']
                lines.append(f'[ext_resource type="Texture2D" path="res://assets/combat/forest_v2/{f["path"]}" id="{key}"]')
                resources.extend([f'[sub_resource type="AtlasTexture" id="{key}"]',f'atlas = ExtResource("{key}")',f'region = Rect2(0, 0, {w}, {h})',f'margin = Rect2({600-ax}, {650-ay}, {1200-w}, {800-h})',''])
            seq=list(range(len(textures)))
            if spec['pingpong']:seq+=list(range(len(textures)-2,0,-1))
            animations.append((clip,spec,[textures[i] for i in seq]))
        lines+=['']+resources+['[resource]','animations = [']
        for i,(clip,spec,seq) in enumerate(animations):
            lines+=['{','"frames": [']
            lines+=['{"duration": 1.0, "texture": SubResource("'+key+'")}'+(',' if j<len(seq)-1 else '') for j,key in enumerate(seq)]
            lines += ['],','"loop": '+str(spec['loop']).lower()+',','"name": &"'+clip+'",','"speed": '+str(1000/spec['ms']),'}'+(',' if i<len(animations)-1 else '')]
        lines+= [']',''];(ROOT/'prepared'/unit.capitalize()/'frames.tres').write_text('\n'.join(lines))
    (ROOT/'library.json').write_text(json.dumps(library,indent=2)+'\n')
    (ROOT/'source_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print('Prepared',len(audit),'sequences; originals unchanged; local Wolf Idle frame-12 paw correction recorded')

if __name__=='__main__':
    # Keep the documented v2 CLI from accidentally restoring the old ghost masks.
    # The repair imports main() above as its deterministic baseline, so no recursion.
    from repair_combat_opacity import main as prepare_readable
    prepare_readable()
