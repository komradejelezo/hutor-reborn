#!/usr/bin/env python3
"""Technical import only: preserve source RGB, key edge-connected black, register feet.

No painting, inferred anatomy, blur, frame interpolation or non-uniform scaling.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]/'assets/combat/animations_v1'
# Curate unsafe source phases; retain originals and explicit reasons in audit JSON.
CURATED={'Hans/Victory':list(range(1,9))+[11,12],
         'Wolf/Attack':list(range(1,11))+list(range(22,25))}
MS={'Hans/Idle':380,'Hans/Attack':70,'Hans/Hit':65,'Hans/Dodge':52,'Hans/Victory':85,'Hans/Death':75,'Hans/Use_Invoke':70,
    'Wolf/Idle':130,'Wolf/Attack':65,'Wolf/Death':65,'Leshy/Idle':155,'Leshy/Attack':65,'Leshy/Death':75}
IMPACT={'Hans/Attack':6,'Wolf/Attack':7,'Leshy/Attack':12,'Hans/Use_Invoke':7}

def clean(path,kind):
    source=Image.open(path);rgb=np.array(source.convert('RGBA')).copy();changed=0
    if source.mode!='RGBA':
        dark=rgb[:,:,:3].max(axis=2)<=8
        labels,n=ndimage.label(dark)
        edges=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]));edges=edges[edges!=0]
        outside=np.isin(labels,edges);rgb[outside,3]=0;changed=int(outside.sum())
    if kind=='Hans/Dodge':
        # Known detached horizontal guide at the top edge; never touch body pixels.
        labels,n=ndimage.label(rgb[:,:,3]>0)
        for i,box in enumerate(ndimage.find_objects(labels),1):
            if box and box[0].start<5 and box[0].stop<=5 and box[1].stop-box[1].start>80:
                mask=labels==i;rgb[mask,3]=0;changed+=int(mask.sum())
    return Image.fromarray(rgb),changed

def feet(image):
    a=np.array(image)[:,:,3];ys,xs=np.where(a>128)
    if not len(xs):return [image.width/2,image.height-1],(0,0,0,0)
    top,bottom=int(ys.min()),int(ys.max())+1
    counts=(a>128).sum(axis=1);valid=np.where((np.arange(a.shape[0])>top+(bottom-top)*.80)&(counts>=max(5,image.width*.02)))[0]
    floor=int(valid[-1])+1 if len(valid) else bottom
    xx=np.where(a[max(top,floor-int((bottom-top)*.15)):floor]>128)[1]
    return [round(float((xx.min()+xx.max())/2),1),floor],image.getbbox()

def main():
    manifest=json.loads((ROOT/'manifest.json').read_text());audit=[];sequences={};reference={}
    for entry in manifest:
        kind=entry['animation'];unit,clip=kind.split('/');files=sorted((ROOT/'assets'/kind).glob('*.png'))
        # A 4284x358 strip is not the thirteenth Dodge pose.
        files=[p for p in files if not p.stem.endswith('strip')]
        images=[];info=[]
        for path in files:
            im,changed=clean(path,kind);anchor,bbox=feet(im);images.append(im)
            out=ROOT/'prepared'/unit/clip/path.name;out.parent.mkdir(parents=True,exist_ok=True);im.save(out)
            info.append({'source':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'path':str(out.relative_to(ROOT)),'size':list(im.size),'anchor':anchor,'bbox':list(bbox),
                'alpha_changed':changed,'source_mode':Image.open(path).mode})
        first=info[0];reference[kind]=first['bbox'][3]-first['bbox'][1]
        sequences[kind]=(entry,info)
        audit.append({'animation':kind,'manifest_frames':entry['frames'],'actual_individual_frames':len(info),'frames':info})
    # The supplied Hans/Leshy Idle lost interior RGB with alpha=0. Use quiet,
    # intact RGB poses from those same supplied characters instead.
    idle_entry=sequences['Hans/Idle'][0]
    hans_attack=sequences['Hans/Attack'][1]
    sequences['Hans/Idle']=(idle_entry,[hans_attack[i-1] for i in [11,12,1]])
    hans_idle=sequences['Hans/Idle'][1][0]['bbox']
    reference['Hans/Idle']=hans_idle[3]-hans_idle[1]
    idle_entry=sequences['Leshy/Idle'][0]
    sequences['Leshy/Idle']=(idle_entry,sequences['Leshy/Attack'][1][:6])
    reference['Leshy/Idle']=reference['Leshy/Attack']
    # Establish calibration from the first unextended pose, not raised weapons/death width.
    library={}
    for kind,(entry,info) in sequences.items():
        unit,clip=kind.split('/');idle_height=reference[unit+'/Idle'];scale=idle_height/reference[kind]
        order=CURATED.get(kind,list(range(1,len(info)+1)))
        # Death must change posture naturally; only register the original ground, never its centroid.
        ax=info[0]['anchor'][0]
        frames=[]
        for index in order:
            f=info[index-1];ay=f['anchor'][1]
            frames.append({**f,'origin':[ax,ay]})
        library.setdefault(unit.lower(),{})[clip.lower()]={'frames':frames,'ms':MS[kind],'scale':scale,
            'pingpong':entry['playback']=='loop_pingpong','loop':clip=='Idle','hold':clip=='Death',
            'impact':IMPACT.get(kind,0),'source_count':len(info),'used_indices':order,
            'derived_from':{'Leshy/Idle':'Leshy/Attack quiet lead-in 1..6',
                'Hans/Idle':'Hans/Attack quiet recovery 11,12,1'}.get(kind,kind)}
        print(kind,'ref-height',reference[kind],'scale',round(scale,3),'first foot',info[0]['anchor'],'used',len(order))
    (ROOT/'library.json').write_text(json.dumps(library,indent=2)+'\n')
    (ROOT/'source_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    # Explicit padded full-frame AtlasTexture resources, editable in Godot.
    for unit,clips in library.items():
        lines=['[gd_resource type="SpriteFrames" format=3]',''];idx=0;resources=[];animations=[]
        for clip,spec in clips.items():
            textures=[]
            for f in spec['frames']:
                idx+=1;key='frame_'+str(idx);textures.append(key)
                lines.append(f'[ext_resource type="Texture2D" path="res://assets/combat/animations_v1/{f["path"]}" id="{key}"]')
                w,h=f['size'];ax,ay=f['origin']
                resources.extend([f'[sub_resource type="AtlasTexture" id="{key}"]',f'atlas = ExtResource("{key}")',f'region = Rect2(0, 0, {w}, {h})',f'margin = Rect2({600-ax}, {650-ay}, {1200-w}, {800-h})',''])
            order=list(range(len(textures)))
            if spec['pingpong']:order+=list(range(len(textures)-2,0,-1))
            animations.append({'name':clip,'loop':spec['loop'],'fps':1000/spec['ms'],'textures':[textures[i] for i in order]})
        lines.append('');lines+=resources;lines.append('[resource]');lines.append('animations = [')
        for j,a in enumerate(animations):
            lines+=['{','"frames": [']
            lines += ['{"duration": 1.0, "texture": SubResource("'+key+'")}'+(',' if n<len(a['textures'])-1 else '') for n,key in enumerate(a['textures'])]
            lines += ['],','"loop": '+str(a['loop']).lower()+',','"name": &"'+a['name']+'",','"speed": '+str(a['fps']),'}'+(',' if j<len(animations)-1 else '')]
        lines+= [']',''];(ROOT/'prepared'/unit.capitalize()/'frames.tres').write_text('\n'.join(lines))

if __name__=='__main__':main()
