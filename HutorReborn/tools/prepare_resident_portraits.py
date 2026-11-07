"""Slice reviewed generated atlases only. Full source atlases remain in the project.
No recolouring, painting, sharpening, aspect distortion or substitution of sprite art.
"""
from pathlib import Path
import json,hashlib
from PIL import Image
P=Path(__file__).resolve().parents[1]
OUT=P/'assets/npc/stage47/portraits'
GROUPS={'elders_inn':['elder','innkeeper','innkeeper_wife'],'woodcutter_family':['woodcutter','woodcutter_wife','woodcutter_son'],'herbalist_and_old_man':['herbalist','herbalist_brother','old_man']}
EMOTIONS=['neutral','joy','displeased','anxious']
records=[]
for group,ids in GROUPS.items():
 source=OUT/'source'/(group+'.png');image=Image.open(source).convert('RGBA')
 assert image.width%4==0 and image.height%3==0 and image.width//4==image.height//3
 size=image.width//4
 assert size>=360,"Reviewed portrait atlas cells must be at least 360px"
 for row,id in enumerate(ids):
  folder=OUT/id;folder.mkdir(parents=True,exist_ok=True)
  for col,emotion in enumerate(EMOTIONS):
   # A centered 2:3 bust crop fits the existing tall portrait frame.
   # Integer 240x360 -> 128x192 is exactly uniform; no aspect distortion.
   left=col*size+(size-240)//2;top=row*size+(size-360)//2
   box=[left,top,left+240,top+360]
   tile=image.crop(box).resize((128,192),Image.Resampling.NEAREST)
   target=folder/(emotion+'.png');tile.save(target)
   records.append({'id':id,'emotion':emotion,'path':str(target.relative_to(P)),'source':str(source.relative_to(P)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'box':box,'size':[128,192],'sampling':'Nearest','origin':'AI generated from original resident reference; reviewed, not original sprite frames'})
(OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('Sliced 36 reviewed portrait variants, nine distinct residents, four emotions')
