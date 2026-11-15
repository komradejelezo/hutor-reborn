"""Uniform nearest slicing of reviewed drawn poses; no procedural limb animation."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/elder548';S=B/'source';G=B/'game';TARGET=50.0
frames=[];records=[];groups={};sources={}
def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=200)&~neon,structure=np.ones((2,2)))
 a[:,:,3]=keep*255;a[~keep]=0;return Image.fromarray(a)
for key in ['idle','right','down','up','read','write','inspect','point','think','social']:
 path=S/(key+'.png');im=clean(Image.open(path));a=np.asarray(im);w,h=im.size;items=[]
 for row in range(2):
  y0=round(row*h/2);y1=round((row+1)*h/2);labels,n=nd.label(a[y0:y1,:,3]>0,np.ones((3,3)))
  sizes=np.bincount(labels.ravel());sizes[0]=0;ids=sorted(range(1,n+1),key=lambda i:sizes[i],reverse=True)[:4];bodies=[]
  for i in ids:
   yy,xx=np.nonzero(labels==i);bodies.append((int(xx.min()),int(xx.max()+1),i))
  bodies.sort();edges=[0]+[(bodies[i-1][1]+bodies[i][0])//2 for i in range(1,4)]+[w]
  assert len(bodies)==4,(key,bodies)
  for col,(_,__,label) in enumerate(bodies):
   x0,x1=edges[col:col+2];crop=im.crop((x0,y0,x1,y1));body=labels[:,x0:x1]==label;yy,xx=np.nonzero(body)
   top,bottom=int(yy.min()),int(yy.max());height=bottom-top+1;head_x=float(np.median(xx[yy<top+height*.14]))
   foot=yy>bottom-height*.09
   cx=head_x if key in ['right','down','up'] else float(np.median(xx[foot]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(items[0]['height']) if key in ['read','write','inspect','point','think','social'] else float(np.median([v['height'] for v in items]))
 ratio=TARGET/ref;indices=[]
 for i,v in enumerate(items):
  floor=float(np.median([q['bottom'] for q in items if q['row']==v['row']]))
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  box=cell.getbbox();assert box and min(box)>0 and max(box)<96,(key,i,box)
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
clips={}
for d,k in [('right','right'),('left','right'),('down','down'),('up','up')]:clips['walk_'+d]=[groups[k][i] for i in [0,1,2,4,5,6]]
for d,ids in [('down',[0,1]),('up',[2,3]),('right',[4,5]),('left',[4,5])]:
 clips['idle_'+d]=[groups['idle'][i] for i in ids];clips['turn_'+d]=clips['idle_'+d][:1]
 clips['talk_'+d]=groups['social'][:4] if d=='down' else [groups['social'][i] for i in [4,5,7]] if d in ['left','right'] else clips['idle_'+d]
clips.update({'talk':groups['social'][:4],'work_inspect':groups['inspect'],'work_read':groups['read'],'work_write':groups['write'],'work_think':groups['think'],'point_down':groups['point'][:4],'point_right':groups['point'][4:],'point_left':groups['point'][4:],'point_up':clips['idle_up']})
used=sorted({i for v in clips.values() for i in v});unique=[];new_records=[];remap={};seen={}
for i in used:
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/elder548/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/elder_version = 548','metadata/native_left_clips = PackedStringArray()','animations = [']
for name,ids in clips.items():
 loop=not name.startswith(('work_','point_'));fps=5.5 if name.startswith('walk_') else 4.5 if name.startswith(('work_','point_')) else 2.5
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+= [']',''];(G/'frames.tres').write_text('\n'.join(lines))
(G/'portraits').mkdir(exist_ok=True);im=Image.open(S/'portrait.png').convert('RGB')
for i,name in enumerate(['neutral','joy','displeased','anxious']):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));ratio=max(128/panel.width,192/panel.height)
 panel=panel.resize((round(panel.width*ratio),round(panel.height*ratio)),Image.Resampling.NEAREST);x=(panel.width-128)//2;panel.crop((x,0,x+128,192)).save(G/'portraits'/(name+'.png'))
im=clean(Image.open(S/'props.png'))
for i,(name,target) in enumerate([('parchment_rolled',10),('parchment_open',14),('journal_closed',10),('journal_open',14),('inkwell',4),('quill',8)]):
 panel=im.crop((round(i*im.width/6),0,round((i+1)*im.width/6),im.height));panel=panel.crop(panel.getbbox());ratio=target/max(panel.size)
 panel.resize((max(1,round(panel.width*ratio)),max(1,round(panel.height*ratio))),Image.Resampling.NEAREST).save(G/(name+'.png'))
for key in ['portrait','props']:
 path=S/(key+'.png');sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(Image.open(path).size)}
limits=['Six selected gait phases; left mirrors right once','Rear talk/point uses directed neutral poses','Independent visual review required; hashes do not prove anatomical quality']
manifest={'id':'elder','base':'3de107b','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'sources':sources,'frames':records,'clips':clips,'limits':limits};(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
p=P/'data/visuals/animation_catalog.json';catalog=json.loads(p.read_text());catalog['elder']={'version':54,'correction_version':548,'frames':'res://assets/npc/elder548/game/frames.tres','clips':{k:len(v) for k,v in clips.items()},'limits':limits,'artistic_redesign_complete':False};p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
p=P/'data/visuals/residents.json';profiles=json.loads(p.read_text());profiles['elder']['portraits']={k:'res://assets/npc/elder548/game/portraits/'+k+'.png' for k in ['neutral','joy','displeased','anxious']};p.write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+'\n')
p=P/'dialogues/residents/elder.json';text=p.read_text().replace('res://assets/npc/stage54/game/elder/portraits/','res://assets/npc/elder548/game/portraits/');p.write_text(text)
rows=['idle_down','walk_right','walk_down','walk_up','work_read','work_write','work_inspect','point_down','point_right','work_think','talk','talk_right']
out=Image.new('RGB',(1152,len(rows)*160),(40,44,40));draw=ImageDraw.Draw(out)
for row,name in enumerate(rows):
 for col,i in enumerate(clips[name]):
  cell=frames[i].crop((12,24,84,88)).resize((144,128),Image.Resampling.NEAREST);out.paste(cell,(col*144,row*160+25),cell)
 draw.text((4,row*160),name)
out.save('/workspace/work/stage548/poses.png')
print('Prepared',len(frames),'unique poses;',len(clips),'clip names')
