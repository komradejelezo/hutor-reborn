"""Technical slicing only: uniform nearest sampling, alpha cleanup and foot pivots.
Authoring images are generated/reviewed separately; no procedural limb animation.
"""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/woodcutter_wife544';S=B/'source';G=B/'game'
S.mkdir(parents=True,exist_ok=True);G.mkdir(exist_ok=True);(S/'.gdignore').write_text('')
TARGET=47.5
FILES={'right':3,'down':3,'up':3,'idle':3,'sweep':3,'home':3,'carry':3,'social':3,'lift':4,'laundry':3,'rake':3}
FILES.update({'down_pass':2,'up_pass':2})
frames=[];records=[];groups={};sources={}
def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=128)&~neon,structure=np.ones((2,2)))
 a[:,:,3]=keep*255;a[~keep]=0;return Image.fromarray(a)
for key,cols in FILES.items():
 path=S/(key+'.png');im=clean(Image.open(path));a=np.asarray(im);w,h=im.size;items=[]
 for row in range(2):
  y0=round(row*h/2);y1=round((row+1)*h/2);mask=a[y0:y1,:,3]>0
  labels,n=nd.label(mask,np.ones((3,3)));sizes=np.bincount(labels.ravel());sizes[0]=0
  ids=sorted(range(1,n+1),key=lambda i:sizes[i],reverse=True)[:cols];bodies=[]
  for i in ids:
   yy,xx=np.nonzero(labels==i);bodies.append((int(xx.min()),int(xx.max()+1),i))
  bodies.sort();edges=[0]+[(bodies[i-1][1]+bodies[i][0])//2 for i in range(1,cols)]+[w]
  assert len(bodies)==cols
  for col,(_,__,label) in enumerate(bodies):
   x0,x1=edges[col:col+2];crop=im.crop((x0,y0,x1,y1));body=labels[:,x0:x1]==label;yy,xx=np.nonzero(body)
   top,bottom=int(yy.min()),int(yy.max());height=bottom-top+1
   head_x=float(np.median(xx[yy<top+height*.14]))
   if key in ['right','down','up','carry','down_pass','up_pass']:cx=head_x
   else:
    # Keep the moving tool/basket out of the foot anchor measurement.
    foot=(yy>bottom-height*.12)&(abs(xx-head_x)<height*.16)
    if foot.sum()<12:foot=yy>bottom-height*.12
    cx=float(np.median(xx[foot]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(items[0]['height']) if key in ['sweep','home','social','lift','laundry','rake'] else float(np.median([v['height'] for v in items]))
 ratio=TARGET/ref;indices=[]
 for i,v in enumerate(items):
  floor=float(np.median([q['bottom'] for q in items if q['row']==v['row']]))
  # Reviewed shoe-pair anchors; a floor basket or broom is not a foot.
  if key=='lift' and i in {1:199,2:201,4:236,5:179,6:187,7:192}:
   v['cx']={1:199,2:201,4:236,5:179,6:187,7:192}[i];floor=425
  if key in ['sweep','rake']:
   v['cx']=[171.5,141,136.5,152.5,104,132.5][i];floor=610 if i<3 else 606
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  assert cell.getbbox(),(key,i)
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
clips={'walk_right':groups['right'],'walk_left':groups['right'],'walk_down':groups['down'],'walk_up':groups['up'],'idle_down':groups['idle'][:2],'idle_up':groups['idle'][2:4],'idle_right':groups['idle'][4:6],'idle_left':groups['idle'][4:6],'talk':groups['social'][:3],'rest':groups['social'][3:6],'work_sweep':groups['sweep'],'work_rake':groups['rake'],'work_cook':groups['home'][:3],'work_wipe':groups['home'][3:6],'work_sort':[groups['home'][3],groups['home'][5]],'work_laundry':groups['laundry'][2:5],'work_rest':groups['social'][3:6],'carry_basket':groups['carry'],'work_carry':groups['carry'],'pick_up_basket':[groups['idle'][4],groups['lift'][1],groups['lift'][2],groups['lift'][4]],'put_down_basket':groups['lift'][4:8],'kneel_down':groups['laundry'][:3],'stand_up':[groups['laundry'][5],groups['laundry'][1],groups['laundry'][0]]}
for direction in ['down','up']:
 clips['walk_'+direction]=[groups[direction][0],groups[direction+'_pass'][0],groups[direction+'_pass'][1],groups[direction][3],groups[direction+'_pass'][2],groups[direction+'_pass'][3]]
clips['work_kneel_down']=clips['kneel_down'];clips['work_stand_up']=clips['stand_up']
# Detach the already released basket. Keep it at a stable floor position while
# the last empty-handed pose straightens, rather than drawing it twice.
released=frames[groups['lift'][6]];labels,n=nd.label(np.asarray(released)[:,:,3]>0,np.ones((3,3)))
sizes=np.bincount(labels.ravel());sizes[0]=0;body=int(np.argmax(sizes));sizes[body]=0;basket=int(np.argmax(sizes))
assert sizes[basket]>50
arr=np.asarray(released).copy();arr[labels!=basket]=0;obj=Image.fromarray(arr);ground_box=obj.getbbox();obj.crop(ground_box).save(G/'basket_ground.png')
last=groups['lift'][7];arr=np.asarray(frames[last]).copy();labels,n=nd.label(arr[:,:,3]>0,np.ones((3,3)));sizes=np.bincount(labels.ravel());sizes[0]=0;body=int(np.argmax(sizes));arr[labels!=body]=0;frames[last]=Image.fromarray(arr)
for d in ['down','up','right','left']:
 clips['turn_'+d]=[clips['idle_'+d][0]];clips['talk_'+d]=clips['talk'] if d=='down' else clips['idle_'+d]
# Alias only exact native duplicates, never pad gait with repeated drawings.
used=sorted({i for v in clips.values() for i in v});unique=[];new_records=[];remap={};seen={}
for i in used:
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/woodcutter_wife544/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/wife_version = 544','metadata/native_left_clips = PackedStringArray()','animations = [']
for name,ids in clips.items():
 loop=name not in ['pick_up_basket','put_down_basket','kneel_down','stand_up','work_kneel_down','work_stand_up','work_rest','rest']
 fps=8 if name.startswith('walk_') or name in ['carry_basket','work_carry'] else 6 if name in ['work_sweep','work_rake','pick_up_basket','put_down_basket','kneel_down','stand_up','work_kneel_down','work_stand_up'] else 2.5 if name.startswith(('idle_','turn_')) else 4
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+= [']',''];(G/'frames.tres').write_text('\n'.join(lines))
manifest={'id':'woodcutter_wife','base':'0a48dab','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'ground_basket_box':ground_box,'sources':sources,'frames':records,'clips':clips,'limits':['Left movement mirrors right once','Side/rear talk uses directional neutral poses','Basket pickup/carry/placement and table wipe are diagnostic clips, not new schedule tasks']}
(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
parser=argparse.ArgumentParser();parser.add_argument('--preview',type=Path);args=parser.parse_args()
if args.preview:
 names=['idle_down','walk_down','walk_up','walk_right','work_sweep','work_cook','work_wipe','work_laundry','carry_basket','pick_up_basket']
 out=Image.new('RGB',(1152,len(names)*192),(42,46,42));draw=ImageDraw.Draw(out)
 for row,name in enumerate(names):
  for col,i in enumerate(clips[name]):
   cell=frames[i].resize((192,192),Image.Resampling.NEAREST);out.paste(cell,(col*192,row*192),cell)
  draw.text((4,row*192),name)
 out.save(args.preview)
print('Prepared',len(frames),'unique poses;',len(clips),'clip names')
