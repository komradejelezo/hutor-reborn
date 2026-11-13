"""Reproducible technical alpha cleanup, uniform Nearest slicing, no limb synthesis."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/innkeeper_wife547';S=B/'source';G=B/'game';TARGET=48
frames=[];records=[];groups={};sources={}
def clean(im):
 a=np.array(im.convert('RGBA'));r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=200)&~neon,structure=np.ones((2,2)));a[~keep]=0;a[:,:,3]=keep*255
 return Image.fromarray(a)
keys=['idle','right','down','up','cook','cut','wipe','dishes','serve','carry','carry_vertical','social','sweep']
for key in keys:
 path=S/(key+'.png');im=clean(Image.open(path));a=np.array(im);w,h=im.size;items=[]
 for row in range(2):
  y0=round(row*h/2);y1=round((row+1)*h/2);labels,n=nd.label(a[y0:y1,:,3]>0,np.ones((3,3)));sizes=np.bincount(labels.ravel());sizes[0]=0
  ids=sorted(range(1,n+1),key=lambda i:sizes[i],reverse=True)[:4];bodies=[]
  for i in ids:
   yy,xx=np.nonzero(labels==i);bodies.append((int(xx.min()),int(xx.max()+1),i))
  bodies.sort();assert len(bodies)==4,(key,bodies)
  edges=[0]+[(bodies[i-1][1]+bodies[i][0])//2 for i in range(1,4)]+[w]
  for col,(_,__,label) in enumerate(bodies):
   x0,x1=edges[col:col+2];crop=im.crop((x0,y0,x1,y1));yy,xx=np.nonzero(labels[:,x0:x1]==label)
   top,bottom=int(yy.min()),int(yy.max());height=bottom-top+1;head=float(np.median(xx[yy<top+height*.13]))
   # A broom touches the floor alongside boots; never use it as the horizontal pivot.
   cx=head if key in ['right','down','up','carry','carry_vertical','sweep'] else float(np.median(xx[yy>bottom-height*.07]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(np.median([v['height'] for v in items])) if key in ['idle','right','down','up','carry','carry_vertical'] else float(items[0]['height'])
 ratio=TARGET/ref;indices=[]
 for i,v in enumerate(items):
  # Align each stationary shoe baseline; keep locomotion's authored foot lift.
  floor=float(np.median([q['bottom'] for q in items if q['row']==v['row']])) if key in ['right','down','up','carry','carry_vertical'] else v['bottom']
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  box=cell.getbbox();assert box and min(box)>0 and max(box)<96,(key,i,box)
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
clips={}
for d,k in [('right','right'),('left','right'),('down','down'),('up','up')]:clips['walk_'+d]=[groups[k][i] for i in [0,1,2,4,5,6]]
for d,ids in [('down',[0,1]),('up',[2,3]),('right',[4,5]),('left',[4,5])]:
 clips['idle_'+d]=[groups['idle'][i] for i in ids];clips['turn_'+d]=clips['idle_'+d][:1]
 clips['talk_'+d]=groups['social'][:4] if d=='down' else clips['idle_'+d]
 clips['carry_idle_'+d]=[groups['carry_vertical'][0 if d=='down' else 4]] if d in ['down','up'] else [groups['carry'][2]]
clips['carry_right']=[groups['carry'][i] for i in [0,1,2,4,5,6]];clips['carry_left']=clips['carry_right']
clips['carry_down']=groups['carry_vertical'][:4];clips['carry_up']=groups['carry_vertical'][4:]
clips.update({'talk':groups['social'][:4],'work_rest':groups['social'][4:],'work_cook':groups['cook'],'work_cut':groups['cut'],'work_wipe':groups['wipe'],'work_dishes':groups['dishes'],'work_pickup':groups['serve'][:4],'work_place':groups['serve'][4:],'work_sweep':groups['sweep']})
unique=[];new_records=[];remap={};seen={}
for i in sorted({i for v in clips.values() for i in v}):
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/innkeeper_wife547/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/innkeeper_wife_version = 547','metadata/native_left_clips = PackedStringArray()','animations = [']
for name,ids in clips.items():
 loop=not (name.startswith('work_') and name!='work_rest');fps=6 if name.startswith('walk_') else (4 if name in ['carry_down','carry_up'] else 6) if name.startswith('carry_') and not name.startswith('carry_idle_') else 4.5 if name.startswith('work_') and name!='work_rest' else 2.5
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+=[']',''];(G/'frames.tres').write_text('\n'.join(lines))
im=Image.open(S/'portrait.png').convert('RGB')
for i,name in enumerate(['neutral','joy','displeased','anxious']):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));ratio=max(128/panel.width,192/panel.height)
 panel=panel.resize((round(panel.width*ratio),round(panel.height*ratio)),Image.Resampling.NEAREST);x=(panel.width-128)//2;panel.crop((x,0,x+128,192)).save(G/'portraits'/(name+'.png'))
im=clean(Image.open(S/'props.png'))
for i,(name,target) in enumerate([('board',14),('tray',12),('mug_cloth',8),('broom',18)]):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));panel=panel.crop(panel.getbbox());ratio=target/max(panel.size)
 panel.resize((max(1,round(panel.width*ratio)),max(1,round(panel.height*ratio))),Image.Resampling.NEAREST).save(G/(name+'.png'))
for key in ['portrait','props']:
 path=S/(key+'.png');sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(Image.open(path).size)}
limits=['Six selected distinct gait poses, not eight padded frames; left mirrors right once','Carrying front/rear has four authored phases','Side/rear conversations use directed neutral poses','Native 48px character has necessarily limited facial/finger detail']
manifest={'id':'innkeeper_wife','base':'3de107b','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'sources':sources,'frames':records,'clips':clips,'limits':limits};(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
p=P/'data/visuals/animation_catalog.json';catalog=json.loads(p.read_text());catalog['innkeeper_wife']={'version':54,'correction_version':547,'frames':'res://assets/npc/innkeeper_wife547/game/frames.tres','clips':{k:len(v) for k,v in clips.items()},'limits':limits,'artistic_redesign_complete':False};p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
p=P/'data/visuals/residents.json';profiles=json.loads(p.read_text());profiles['innkeeper_wife']['portraits']={k:'res://assets/npc/innkeeper_wife547/game/portraits/'+k+'.png' for k in ['neutral','joy','displeased','anxious']};p.write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+'\n')
p=P/'dialogues/residents/innkeeper_wife.json';text=p.read_text();text=text.replace('res://assets/npc/stage54/game/innkeeper_wife/portraits/','res://assets/npc/innkeeper_wife547/game/portraits/');p.write_text(text)
rows=['idle_down','walk_right','walk_down','walk_up','work_cook','work_cut','work_pickup','carry_right','work_place','work_wipe','work_dishes','work_sweep','talk','work_rest']
out=Image.new('RGB',(1152,len(rows)*160),(40,44,40));draw=ImageDraw.Draw(out)
for row,name in enumerate(rows):
 for col,i in enumerate(clips[name]):
  cell=frames[i].crop((16,25,80,88)).resize((128,126),Image.Resampling.NEAREST);out.paste(cell,(col*144,row*160+25),cell)
 draw.text((4,row*160),name)
out.save('/workspace/work/stage547/poses.png');print('Prepared',len(frames),'unique poses;',len(clips),'clips')
