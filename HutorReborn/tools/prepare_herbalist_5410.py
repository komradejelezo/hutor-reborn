"""Technical alpha cleanup and whole-pose Nearest slicing; no painted/warped limbs."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/herbalist5410';S=B/'source';G=B/'game';TARGET=47.5
frames=[];records=[];groups={};sources={}
def clean(im):
 a=np.array(im.convert('RGBA'));r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=200)&~neon,structure=np.ones((2,2)));a[~keep]=0;a[:,:,3]=keep*255
 return Image.fromarray(a)
for key in ['idle','right','left','down','up','gather','sort','grind','brew','read','social']:
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
   # Align whole poses to boot contact; gaits keep their drawn head axis.
   cx=float(np.median(xx[yy>bottom-height*.08]))
   if key in ['right','left','down','up']:cx=float(np.median(xx[yy<top+height*.13]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(items[0]['height']) if key in ['gather','sort','grind','brew','read','social'] else float(np.median([v['height'] for v in items]))
 target=TARGET
 ratio=target/ref;indices=[]
 for i,v in enumerate(items):
  floor=float(np.median([q['bottom'] for q in items if q['row']==v['row']])) if key in ['right','left','down','up'] else v['bottom']
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  box=cell.getbbox();assert box and min(box)>0 and max(box)<96,(key,i,box)
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
clips={}
for d in ['down','up','right','left']:clips['walk_'+d]=[groups[d][i] for i in [0,1,2,4,5,6]]
for d,ids in [('down',[0,1]),('up',[2,3]),('right',[4,5]),('left',[6,7])]:
 clips['idle_'+d]=[groups['idle'][i] for i in ids];clips['turn_'+d]=clips['idle_'+d][:1]
 clips['talk_'+d]=groups['social'][:4] if d=='down' else groups['social'][4:] if d=='right' else clips['idle_'+d]
clips.update({'talk':groups['social'][:4],'gather_herbs':groups['gather'],'sort_herbs':groups['sort'],'grind_herbs':groups['grind'],'brew_infusion':groups['brew'],'read_herbal':groups['read']})
clips['work_gather']=clips['gather_herbs'];clips['work_grind']=clips['grind_herbs'];clips['work_table']=clips['sort_herbs']
unique=[];new_records=[];remap={};seen={}
for i in sorted({i for ids in clips.values() for i in ids}):
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/herbalist5410/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/herbalist_version = 5410','metadata/native_left_clips = PackedStringArray("walk_left", "idle_left", "turn_left", "talk_left")','animations = [']
for name,ids in clips.items():
 loop=name.startswith(('walk_','idle_','turn_','talk'));fps=5.5 if name.startswith('walk_') else 1.2 if name.startswith(('idle_','turn_')) else 3.5 if name in ['gather_herbs','work_gather'] else 4 if name not in ['talk','talk_down','talk_up','talk_left','talk_right'] else 2.5
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+=[']',''];(G/'frames.tres').write_text('\n'.join(lines))
im=Image.open(S/'portrait.png').convert('RGB')
for i,name in enumerate(['neutral','joy','displeased','anxious']):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));ratio=max(128/panel.width,192/panel.height)
 panel=panel.resize((round(panel.width*ratio),round(panel.height*ratio)),Image.Resampling.NEAREST);x=(panel.width-128)//2;panel.crop((x,0,x+128,192)).save(G/'portraits'/(name+'.png'))
im=clean(Image.open(S/'props.png'))
for i,(name,target) in enumerate([('mortar',8),('pestle',5),('herbs_mat',12),('book_closed',10),('book_open',12)]):
 panel=im.crop((round(i*im.width/5),0,round((i+1)*im.width/5),im.height));panel=panel.crop(panel.getbbox());ratio=target/max(panel.size)
 panel.resize((max(1,round(panel.width*ratio)),max(1,round(panel.height*ratio))),Image.Resampling.NEAREST).save(G/(name+'.png'))
for key in ['portrait','props']:
 p=S/(key+'.png');sources[key]={'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':list(Image.open(p).size)}
limits=['Six selected distinct gait poses per direction, left independently drawn','No run: existing behaviour does not use it and four quality run directions not available','Side-left and rear talk use independent quiet idle poses','Crouch uses one whole-sheet scale; native facial and finger detail remains limited']
m={'id':'herbalist','base':'9122b11','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'sources':sources,'frames':records,'clips':clips,'limits':limits};(B/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
p=P/'data/visuals/animation_catalog.json';d=json.loads(p.read_text());d['herbalist']={'version':54,'correction_version':5410,'frames':'res://assets/npc/herbalist5410/game/frames.tres','clips':{k:len(v) for k,v in clips.items()},'limits':limits,'artistic_redesign_complete':False};p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=P/'data/visuals/residents.json';d=json.loads(p.read_text());d['herbalist']['portraits']={k:'res://assets/npc/herbalist5410/game/portraits/'+k+'.png' for k in ['neutral','joy','displeased','anxious']};p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=P/'dialogues/residents/herbalist.json';p.write_text(p.read_text().replace('res://assets/npc/stage54/game/herbalist/portraits/','res://assets/npc/herbalist5410/game/portraits/'))
rows=['idle_down','idle_left','walk_right','walk_left','walk_down','walk_up','gather_herbs','sort_herbs','grind_herbs','brew_infusion','read_herbal','talk']
out=Image.new('RGB',(1152,len(rows)*155),(40,44,40));draw=ImageDraw.Draw(out)
for row,name in enumerate(rows):
 for col,i in enumerate(clips[name]):
  cell=frames[i].crop((12,24,84,89)).resize((144,130),Image.Resampling.NEAREST);out.paste(cell,(col*144,row*155+23),cell)
 draw.text((4,row*155),name)
out.save('/workspace/work/stage5410/poses.png');print(len(frames),'unique poses',len(clips),'clips')
