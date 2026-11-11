"""Read-only native-pixel measurements and annotated evidence, not anatomy deformation.
Head boxes and pelvis lines are manually observed landmarks, with clothing ambiguity.
Usage: python tools/measure_npc_proportions.py OUTPUT_DIRECTORY
"""
from pathlib import Path
import json,sys,re
import numpy as np
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
m=json.loads((P/'assets/npc/stage54/manifest.json').read_text())
# Native-pixel selection rectangles include hair/headgear. Pelvis hidden by clothing: estimates ±3px.
marks={'hans':([42,34,54,46],63),'elder':([40,35,57,49],65),'innkeeper':([41,33,57,47],64),'innkeeper_wife':([41,36,56,50],64),'woodcutter':([41,34,57,50],63),'woodcutter_wife':([42,36,56,49],63),'woodcutter_son':([44,50,54,62],70),'herbalist':([40,35,58,51],64),'herbalist_brother':([40,34,57,49],63),'old_man':([40,39,58,55],66)}
items=[];a=Image.open(P/'assets/characters/hans/frames/walk_down_00.png').convert('RGBA');native=Image.new('RGBA',(96,96));native.paste(a.resize((40,56),Image.Resampling.NEAREST),(28,29));items.append(('hans',native,a.getbbox(),1/24))
for id,r in m['residents'].items():
 a=Image.open(P/'assets/npc/stage54/game'/id/'atlas.png').convert('RGBA');i=r['clips']['walk_down'][0];c=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));items.append((id,c,c.getbbox(),1.0))
measure={};comp=Image.new('RGB',(1440,330),(56,60,55));draw=ImageDraw.Draw(comp)
for index,(id,c,box,scale) in enumerate(items):
 roi,pelvis=marks[id];head=c.crop(roi).getbbox();torso=c.crop((0,51 if id!='woodcutter_son' else 63,96,61 if id!='woodcutter_son' else 69)).getbbox()
 measure[id]={'representative':'walk_down/0','alpha_height':round((box[3]-box[1])*scale,2),'alpha_width':round((box[2]-box[0])*scale,2),'head_roi':roi,'head_gear_bbox_size':[head[2]-head[0],head[3]-head[1]],'torso_silhouette_width':torso[2]-torso[0],'pelvis_line_estimate':pelvis,'leg_to_pivot_estimate':82-pelvis,'leg_uncertainty':3,'node_scale':scale,'side_idle_node_scale':1/21 if id=='hans' else 1,'pivot_in_source':[480,1280] if id=='hans' else [48,82],'world_pivot':[0,0],'native_bbox':c.getbbox(),'head_uncertainty':1}
 cc=c.resize((288,288),Image.Resampling.NEAREST);bb=c.getbbox();cc=cc.crop((bb[0]*3,0,bb[2]*3,288));x=index*144+72-cc.width//2;comp.paste(cc,(x,0),cc);draw.text((index*144+2,290),id.replace('woodcutter','wood'));draw.text((index*144+2,307),'BEFORE = AFTER body')
 # Independent labelled landmark evidence; leg line is NOT a visibility claim under a dress.
 ev=Image.new('RGB',(384,424),(56,60,55));ev.paste(c.resize((384,384),Image.Resampling.NEAREST),(0,24),c.resize((384,384),Image.Resampling.NEAREST));d=ImageDraw.Draw(ev);d.rectangle(tuple(int(v*4) for v in [roi[0],roi[1]+6,roi[2],roi[3]+6]),outline=(218,171,80),width=1);d.line((0,pelvis*4+24,383,pelvis*4+24),fill=(190,115,80));d.line((0,82*4+24,383,82*4+24),fill=(100,170,120));d.text((4,4),id+' | head ROI / estimated pelvis / pivot');ev.save(out/(id+'-landmarks.png'))
comp.save(out/'proportions-before-after.png');(out/'measurements.json').write_text(json.dumps(measure,indent=2)+'\n')
rows=['| Персонаж | Высота / ширина альфа, px | Ширина торса с руками, px | Голова с убором, px (±1) | Таз–опора, px (≈±3) | Scale | Pivot исходника |','|---|---|---|---|---|---|---|']
for id,r in measure.items():rows.append(f"| {id} | {r['alpha_height']} / {r['alpha_width']} | {r['torso_silhouette_width']} | {r['head_gear_bbox_size'][0]} × {r['head_gear_bbox_size'][1]} | ≈{r['leg_to_pivot_estimate']} | {r['node_scale']:.5f} | {r['pivot_in_source']} |")
(out/'table.md').write_text('\n'.join(rows)+'\n')
print('\n'.join(rows))
