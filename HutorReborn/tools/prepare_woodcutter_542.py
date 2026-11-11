"""Pilot-only artwork preparation. Technical alpha cleanup/cropping; no limb deformation.
Generated authoring sheets are kept apart from playable PNG. Pillow/numpy/scipy.
"""
from pathlib import Path
import json,hashlib,argparse
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/woodcutter542';S=B/'source';G=B/'game';S.mkdir(parents=True,exist_ok=True);G.mkdir(exist_ok=True);(S/'.gdignore').write_text('')
FILES={'right':('exec-7fb15ede-a611-4471-b193-a4eb82c3a8e7.png',3),'down':('exec-9b30c457-b24d-47e0-888b-da3bdd17f280.png',3),'up':('exec-1f980e7a-4622-482e-a19d-338a5bf5acdb.png',3),'idle':('exec-b03d1f0e-40ef-4a73-bf5f-788616aa35d0.png',4),'chop':('exec-50ef29a2-719e-476c-9602-8d3911d4d0b2.png',4),'carry':('exec-7982c1fb-bf2e-4a0d-a667-0fa7ca893a09.png',3),'lift':('exec-fd279a32-3ddc-4ea2-93e3-2ebce72a16ac.png',4),'social':('exec-32da0783-1a3e-4ebe-b8e5-d196663d06d9.png',3)}
TARGET=49.5;frames=[];records=[];groups={};info={}
FILES.update({'carry_down':('exec-1bb51c2b-f2e1-43cc-85cd-c60934b36716.png',3),'carry_up':('exec-94fba089-6c41-4199-944f-7adf732a0b55.png',3),'carry_neutral':('exec-c9194574-85bb-4073-837f-642dcd045531.png',3)})
def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=[a[:,:,n].astype(int) for n in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=(a[:,:,3]>=128)&~neon;keep=nd.binary_opening(keep,structure=np.ones((2,2)))
 a[:,:,3]=keep*255;a[~keep]=0;return Image.fromarray(a)
def components(mask,count):
 labels,n=nd.label(mask,np.ones((3,3)));sizes=np.bincount(labels.ravel());sizes[0]=0;ids=sorted(range(1,n+1),key=lambda k:sizes[k],reverse=True)[:count];out=[]
 for id in ids:
  y,x=np.nonzero(labels==id);out.append((x.min(),y.min(),x.max()+1,y.max()+1,id))
 return sorted(out),labels
for key,(filename,cols) in FILES.items():
 destination=S/(key+('_v2' if key=='idle' else '')+'.png')
 if not destination.exists():raise FileNotFoundError('Missing authoring source: '+str(destination))
 im=clean(Image.open(destination));a=np.asarray(im);w,h=im.size;items=[]
 rows=1 if key=='carry_neutral' else 2
 for row in range(rows):
  y0=round(row*h/rows);y1=round((row+1)*h/rows);part=a[y0:y1,:,3]>0;cs,labels=components(part,cols)
  assert len(cs)==cols,(key,len(cs))
  edges=[0]+[int((cs[i-1][2]+cs[i][0])/2) for i in range(1,cols)]+[w]
  for col,c in enumerate(cs):
   x0=edges[col];x1=edges[col+1];crop=im.crop((x0,y0,x1,y1));body=labels[:,x0:x1]==c[4];yy,xx=np.nonzero(body)
   top=int(yy.min());bottom=int(yy.max());height=bottom-top+1
   if key in ['right','down','up','carry','carry_down','carry_up']:
    band=yy<top+height*.16;cx=float(np.median(xx[band]))
   else:
    band=yy>bottom-height*.12;cx=float(np.median(xx[band]))
   items.append({'image':crop,'height':height,'top':top,'bottom':bottom,'cx':cx,'box':[x0,y0,x1,y1],'row':row,'col':col})
 refheight=items[0]['height'] if key in ['chop','lift','social'] else float(np.median([v['height'] for v in items]))
 ratio=TARGET/refheight;indices=[]
 for i,v in enumerate(items):
  foot=float(np.median([q['bottom'] for q in items if q['row']==v['row']]))
  ox=48-v['cx']*ratio;oy=82-foot*ratio
  cell=v['image'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  if not cell.getbbox():raise ValueError((key,i,'empty'))
  indices.append(len(frames));frames.append(cell);records.append({'source':destination.name,'source_index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'height_reference':refheight,'pivot':[48,82]})
 groups[key]=indices;info[key]={'file':destination.name,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'size':[w,h],'figure_count':len(items),'reference_height':refheight,'scale':ratio}
clips={'walk_right':groups['right'],'walk_left':groups['right'],'walk_down':groups['down'],'walk_up':groups['up'],'idle_down':groups['idle'][:2],'idle_up':groups['idle'][2:4],'idle_right':groups['idle'][4:6],'idle_left':groups['idle'][6:8],'chop_wood':groups['chop'],'carry_logs':groups['carry'],'pick_up_log':[groups['idle'][4],groups['lift'][1],groups['lift'][2],groups['lift'][4]],'put_down_log':groups['lift'][4:8],'talk':groups['social'][:3],'rest':groups['social'][3:6]}
clips.update({'carry_right':groups['carry'],'carry_left':groups['carry'],'carry_down':groups['carry_down'],'carry_up':groups['carry_up'],'carry_idle_down':[groups['carry_neutral'][0]],'carry_idle_right':[groups['carry_neutral'][1]],'carry_idle_left':[groups['carry_neutral'][1]],'carry_idle_up':[groups['carry_neutral'][2]]})
# Keep genuine distinct native frames only, rather than formally padding breathing.
for name in list(clips):
 if name.startswith('idle_'):
  unique=[];seen=set()
  for i in clips[name]:
   digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
   if digest not in seen:unique.append(i);seen.add(digest)
  clips[name]=unique
for d in ['down','up','right','left']:clips['turn_'+d]=[clips['idle_'+d][0]]
clips.update({'talk_down':clips['talk'],'talk_left':clips['idle_left'],'talk_right':clips['idle_right'],'talk_up':clips['idle_up'],'work_chop':clips['chop_wood'],'work_carry':clips['carry_logs'],'work_pick_up':clips['pick_up_log'],'work_put_down':clips['put_down_log'],'work_rest':clips['rest'],'work_inspect':clips['idle_down']})
used=sorted({i for values in clips.values() for i in values});remap={old:new for new,old in enumerate(used)}
frames=[frames[i] for i in used];records=[records[i] for i in used];clips={name:[remap[i] for i in indices] for name,indices in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
# The loose bundle is exactly the authored released object, not unrelated art.
released=frames[clips['put_down_log'][2]]
labels,n=nd.label(np.asarray(released)[:,:,3]>0,np.ones((3,3)))
sizes=np.bincount(labels.ravel());sizes[0]=0
body=int(np.argmax(sizes));sizes[body]=0;bundle=int(np.argmax(sizes))
assert sizes[bundle]>40,'Released bundle must remain a separate component'
arr=np.asarray(released).copy();arr[labels!=bundle]=0
bundle_image=Image.fromarray(arr);box=bundle_image.getbbox()
bundle_image.crop(box).save(G/'placed_logs.png')
text=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/woodcutter542/game/atlas.png" id="1"]','']
for i in range(len(frames)):text += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
text += ['[resource]','metadata/rework_version = 54','metadata/woodcutter_version = 542','metadata/native_left_clips = PackedStringArray("idle_left", "turn_left", "talk_left")','animations = [']
for name,indices in clips.items():
 looping=name.startswith(('walk_','idle_','turn_','talk','carry_')) or name in ['carry_logs','work_carry']
 fps=8 if name.startswith(('walk_','carry_')) or name in ['chop_wood','work_chop','carry_logs','work_carry'] else 6 if name in ['pick_up_log','put_down_log','work_pick_up','work_put_down'] else 2.5 if name.startswith(('idle_','turn_')) else 3
 durations=[2,1,1,1.2,.7,.8,1,2] if name in ['chop_wood','work_chop'] else [1]*len(indices)
 text+=['{','"frames": ['+', '.join('{"duration": '+str(durations[j])+', "texture": SubResource("F'+str(i)+'")}' for j,i in enumerate(indices))+'],',f'"loop": {str(looping).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
text[-1]='}';text+= [']',''];(G/'frames.tres').write_text('\n'.join(text))
(B/'manifest.json').write_text(json.dumps({'npc_id':'woodcutter','base':'4884da5','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'sources':info,'frames':records,'clips':clips,'limits':['Native left idle; left walking mirrors right once','Side/rear talk currently uses neutral directional breathing','Work cycle is demonstrated diagnostically; logging remains scheduled off-map']},indent=2)+'\n')
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--preview',type=Path);args=parser.parse_args();o=Image.new('RGB',(1152,6*192),(42,47,42));d=ImageDraw.Draw(o)
for row,name in enumerate(['walk_down','walk_up','walk_right','chop_wood','carry_logs','pick_up_log']):
 for col,i in enumerate(clips[name][:6]):
  z=frames[i].resize((192,192),Image.Resampling.NEAREST);o.paste(z,(col*192,row*192),z)
 d.text((4,row*192),name)

if args.preview:o.save(args.preview)
print('Prepared',len(frames),'source poses,',len(clips),'compatible names; counts:',{n:len(v) for n,v in clips.items() if n in ['walk_down','walk_up','walk_right','idle_down','chop_wood','carry_logs','pick_up_log','put_down_log','rest','talk']})
