"""Additional archived activity frames only. Prior NPC/Hans PNGs stay untouched."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];OUT=P/'assets/npc/stage46';OUT.mkdir(parents=True,exist_ok=True)
base=json.loads((P/'assets/npc/stage43/sprite_manifest.json').read_text(encoding='utf-8'))['residents']
specs={
 'woodcutter_wife':{'work_cook':('Жена дровосека','Sprite-0010',9,.45),'work_rake':('Жена дровосека','Sprite-0013',3,1)},
 'herbalist':{'work_inspect':('Марта','Sprite-0002',4,1),'work_table':('Марта','Sprite-0006',4,.5)},
 'innkeeper_wife':{'work_cook':('Жена трактирщика','Sprite-0010',4,.48)},
 'innkeeper':{'work_taste':('Трактирщик','Sprite-0008',4,1)},
 'old_man':{'work_think':('Страрик','Sprite-0007',3,1),'work_sit':('Страрик','Sprite-0012',1,1)},
 'woodcutter_son':{'work_kneel':('Сын дровосека','Sprite-0014',4,1)},
}
manifest={}
for npc,clips in specs.items():
    # The inn walk sheets are smaller than the archived 793px action cells.
    # Match an existing action cell, never reuse the small-sheet walk ratio.
    ratio=next(f['scale'] for f in base[npc]['frames'] if f['box'][2]-f['box'][0]==793)
    frames=[];records=[];mapping={}
    for clip,(folder,filename,count,body_fraction) in clips.items():
        path=P/'assets/npc/stage2'/folder/(filename+'.png');image=Image.open(path).convert('RGBA')
        raw=[];anchors=[]
        for index in range(count):
            box=(index*793,0,(index+1)*793,1285);crop=image.crop(box);a=np.array(crop);rgb=a[:,:,:3].astype(int)
            yy=np.arange(1285)[:,None]
            guides=(yy>1285*.9)&(np.abs(rgb[:,:,0]-rgb[:,:,1])<12)&((rgb.max(2)-rgb.min(2))<40)&(rgb.max(2)>90)
            a[guides,3]=0;crop=Image.fromarray(a);raw.append(crop)
            alpha=a[:,:,3]>32;ys,xs=np.nonzero(alpha);top,bottom=ys.min(),ys.max()
            body=(xs<int(793*body_fraction))&(ys>top+(bottom-top)*.28)&(ys<top+(bottom-top)*.7)
            cx=float(np.median(xs[body])) if body.any() else float(np.median(xs))
            feet=alpha.copy();feet[:int(top+(bottom-top)*.7)]=False
            feet[:,:max(0,int(cx-140))]=False;feet[:,min(793,int(cx+140)):]=False
            foot=int(np.nonzero(feet)[0].max()) if feet.any() else int(bottom)
            anchors.append([cx,foot])
        anchor=np.median(np.array(anchors),axis=0);mapping[clip]=[]
        for index,crop in enumerate(raw):
            size=(round(crop.width*ratio),round(crop.height*ratio));small=crop.resize(size,Image.Resampling.NEAREST)
            offset=(48-round(anchor[0]*ratio),82-round(anchor[1]*ratio))
            frame=Image.new('RGBA',(96,96));frame.paste(small,offset)
            assert frame.getbbox(),(npc,clip,index)
            mapping[clip].append(len(frames));frames.append(frame)
            records.append({'clip':clip,'source':str(path.relative_to(P)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'box':[index*793,0,(index+1)*793,1285],'resized':size,'offset':offset,'anchor':anchor.tolist(),'scale':ratio})
    atlas=Image.new('RGBA',(8*96,((len(frames)+7)//8)*96))
    for index,frame in enumerate(frames):atlas.paste(frame,(index%8*96,index//8*96))
    atlas.save(OUT/(npc+'.png'));manifest[npc]={'clips':mapping,'frames':records}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared',sum(len(x['frames']) for x in manifest.values()),'real archived activity frames; seated pose explicitly single-frame')
