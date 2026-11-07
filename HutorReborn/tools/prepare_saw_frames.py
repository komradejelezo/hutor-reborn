"""Cut the original six saw action cells. New resource, no existing PNG edits."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1]
source=P/'assets/npc/stage2/Дровосек/Sprite-ар0.png'
original=Image.open(source).convert('RGBA')
base=json.loads((P/'assets/npc/stage43/sprite_manifest.json').read_text())['residents']['woodcutter']['frames']
ratio=base[0]['scale'];anchor=next(f['source_foot'] for f in base if f['clip']=='work_chop')
atlas=Image.new('RGBA',(576,96));records=[]
for i in range(6):
 box=(i*793,0,(i+1)*793,1285);frame=original.crop(box)
 a=np.array(frame);rgb=a[:,:,:3].astype(int);yy=np.arange(1285)[:,None]
 guides=(yy>1285*.9)&(np.abs(rgb[:,:,0]-rgb[:,:,1])<12)&((rgb.max(2)-rgb.min(2))<40)&(rgb.max(2)>90)
 a[guides,3]=0;size=(round(793*ratio),round(1285*ratio));small=Image.fromarray(a).resize(size,Image.Resampling.NEAREST)
 offset=(48-round(anchor[0]*ratio),82-round(anchor[1]*ratio));cell=Image.new('RGBA',(96,96));cell.paste(small,offset)
 atlas.paste(cell,(i*96,0));records.append({'source':str(source.relative_to(P)),'box':box,'scale':ratio,'size':size,'offset':offset})
out=P/'assets/npc/stage47';out.mkdir(parents=True,exist_ok=True);atlas.save(out/'woodcutter_saw.png')
(out/'animation_manifest.json').write_text(json.dumps({'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'frames':records,'note':'Original saw action; prepared for preview/future work location, not inserted into frozen daily schedules.'},ensure_ascii=False,indent=2)+'\n')
print('Sliced six original saw frames with original body scale and foot anchor')
