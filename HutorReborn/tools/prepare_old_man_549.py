"""Technical alpha cleanup and whole-pose Nearest slicing; no painted/warped limbs."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/old_man549';S=B/'source';G=B/'game';TARGET=46.0
frames=[];records=[];groups={};sources={};seat_height=35.5
def clean(im):
 a=np.array(im.convert('RGBA'));r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=200)&~neon,structure=np.ones((2,2)));a[~keep]=0;a[:,:,3]=keep*255
 return Image.fromarray(a)
for key in ['idle','right','left','down','up','smoke','sit_down','sit_smoke','rest','social']:
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
   top,bottom=int(yy.min()),int(yy.max());height=bottom-top+1
   # Boot pixels outnumber the thin staff tip. Horizontal support belongs to
   # boots, never the hand or the projecting staff. Gaits keep drawn head axis.
   cx=float(np.median(xx[yy>bottom-height*.08]))
   if key in ['right','left','down','up']:cx=float(np.median(xx[yy<top+height*.13]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(items[0]['height']) if key in ['smoke','sit_down','rest','social'] else float(np.median([v['height'] for v in items]))
 target=seat_height if key=='sit_smoke' else TARGET
 ratio=target/ref;indices=[]
 for i,v in enumerate(items):
  floor=float(np.median([q['bottom'] for q in items if q['row']==v['row']])) if key in ['right','left','down','up'] else v['bottom']
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  box=cell.getbbox();assert box and min(box)>0 and max(box)<96,(key,i,box)
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
 if key=='sit_down':seat_height=TARGET*items[-1]['height']/ref
clips={}
for d in ['down','up','right','left']:clips['walk_'+d]=[groups[d][i] for i in [0,1,2,4,5,6]]
for d,ids in [('down',[0,1]),('up',[2,3]),('right',[4,5]),('left',[6,7])]:
 clips['idle_'+d]=[groups['idle'][i] for i in ids];clips['turn_'+d]=clips['idle_'+d][:1]
 clips['talk_'+d]=groups['social'][:4] if d=='down' else groups['social'][4:] if d=='right' else clips['idle_'+d]
clips.update({'talk':groups['social'][:4],'smoke_pipe':groups['smoke'],'sit_down':groups['sit_down'],'stand_up':groups['sit_down'][::-1],'sit_idle':[groups['sit_smoke'][0],groups['sit_smoke'][7]],'sit_smoke':groups['sit_smoke'],'lean_on_staff':groups['rest'][:4],'think':groups['rest'][4:]})
clips['work_smoke']=clips['smoke_pipe'];clips['work_sit']=clips['sit_smoke'];clips['work_think']=clips['think']
unique=[];new_records=[];remap={};seen={}
for i in sorted({i for ids in clips.values() for i in ids}):
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/old_man549/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/old_man_version = 549','metadata/native_left_clips = PackedStringArray("walk_left", "idle_left", "turn_left", "talk_left")','animations = [']
for name,ids in clips.items():
 loop=name.startswith(('walk_','idle_','turn_','talk')) or name=='sit_idle';fps=4.5 if name.startswith('walk_') else 1.2 if name.startswith(('idle_','turn_')) or name=='sit_idle' else 4 if name in ['sit_down','stand_up'] else 3 if name in ['smoke_pipe','sit_smoke','work_smoke','work_sit'] else 2.5
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+=[']',''];(G/'frames.tres').write_text('\n'.join(lines))
im=Image.open(S/'portrait.png').convert('RGB')
for i,name in enumerate(['neutral','joy','displeased','anxious']):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));ratio=max(128/panel.width,192/panel.height)
 panel=panel.resize((round(panel.width*ratio),round(panel.height*ratio)),Image.Resampling.NEAREST);x=(panel.width-128)//2;panel.crop((x,0,x+128,192)).save(G/'portraits'/(name+'.png'))
p=S/'portrait.png';sources['portrait']={'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':list(im.size)}
limits=['Six selected distinct gait phases per direction','Left gait is independently drawn; no staff hand swap by flipping','Stand-up reverses authored sit-down poses','Side-left and rear talks use independent quiet idle poses','Native 46px detail and subtle residual silhouette variation need artistic review']
m={'id':'old_man','base':'4b8346d','target_height':TARGET,'seated_height':seat_height,'canvas':[96,96],'pivot':[48,82],'sources':sources,'frames':records,'clips':clips,'limits':limits};(B/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
p=P/'data/visuals/animation_catalog.json';d=json.loads(p.read_text());d['old_man']={'version':54,'correction_version':549,'frames':'res://assets/npc/old_man549/game/frames.tres','clips':{k:len(v) for k,v in clips.items()},'limits':limits,'artistic_redesign_complete':False};p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=P/'data/visuals/residents.json';d=json.loads(p.read_text());d['old_man']['portraits']={k:'res://assets/npc/old_man549/game/portraits/'+k+'.png' for k in ['neutral','joy','displeased','anxious']};p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=P/'dialogues/residents/old_man.json';p.write_text(p.read_text().replace('res://assets/npc/stage54/game/old_man/portraits/','res://assets/npc/old_man549/game/portraits/'))
rows=['idle_down','idle_left','walk_right','walk_left','walk_down','walk_up','smoke_pipe','sit_down','sit_smoke','lean_on_staff','think','talk']
out=Image.new('RGB',(1152,len(rows)*155),(40,44,40));draw=ImageDraw.Draw(out)
for row,name in enumerate(rows):
 for col,i in enumerate(clips[name]):
  cell=frames[i].crop((12,25,84,89)).resize((144,128),Image.Resampling.NEAREST);out.paste(cell,(col*144,row*155+23),cell)
 draw.text((4,row*155),name)
out.save('/workspace/work/stage549/poses.png');print(len(frames),'unique poses, seated height',seat_height)
