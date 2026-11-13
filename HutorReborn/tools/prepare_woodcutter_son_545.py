"""Reviewed drawn poses -> native nearest atlas. No procedural limb animation.
Original authoring sheets remain intact; only alpha cleanup and uniform sampling.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1]; B=P/'assets/npc/woodcutter_son545'; S=B/'source'; G=B/'game'
TARGET=35.5
frames=[];records=[];groups={};sources={}
def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=[a[:,:,i].astype(float) for i in range(3)]
 neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))|((r>180)&(g>170)&(b<65))
 keep=nd.binary_opening((a[:,:,3]>=128)&~neon,structure=np.ones((2,2)))
 a[:,:,3]=keep*255;a[~keep]=0;return Image.fromarray(a)
for key in ['right','down','up','run_right','run_down','run_up','idle','play','jump']:
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
   cx=head_x if key in ['right','down','up','run_right','run_down','run_up'] else float(np.median(xx[foot]))
   items.append(dict(crop=crop,top=top,bottom=bottom,height=height,cx=cx,row=row,box=[x0,y0,x1,y1]))
 ref=float(items[0]['height']) if key=='play' else float(items[7]['height']) if key=='jump' else float(np.median([v['height'] for v in items]))
 ratio=TARGET/ref;indices=[]
 for i,v in enumerate(items):
  same=[q['bottom'] for q in items if q['row']==v['row']]
  floor=float(max(same) if key in ['play','jump'] else np.median(same))
  ox=48-v['cx']*ratio;oy=82-floor*ratio
  cell=v['crop'].transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
  assert cell.getbbox() and all(cell.getbbox()[i]>0 for i in [0,1]) and cell.getbbox()[2]<96 and cell.getbbox()[3]<96,(key,i,cell.getbbox())
  indices.append(len(frames));frames.append(cell);records.append({'source':path.name,'index':i,'box':v['box'],'scale_uniform':ratio,'offset':[ox,oy],'pivot':[48,82]})
 groups[key]=indices;sources[key]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h],'reference_height':ref,'scale':ratio}
clips={}
# Six selected phases: contact/passing/rising on each leg. Discard near repeats.
for mode in ['walk','run']:
 for d,k in [('right','right'),('left','right'),('down','down'),('up','up')]:
  clips[mode+'_'+d]=[groups[('run_' if mode=='run' else '')+k][i] for i in [0,2,3,4,6,7]]
for d,ids in [('down',[0,1]),('up',[2,3]),('right',[4,5]),('left',[4,5])]:
 clips['idle_'+d]=[groups['idle'][i] for i in ids];clips['turn_'+d]=clips['idle_'+d][:1]
 clips['talk_'+d]=[groups['jump'][6],groups['jump'][5],groups['jump'][7]] if d in ['right','left'] else clips['idle_'+d]
clips.update({'talk':[groups['jump'][6],groups['jump'][5],groups['jump'][7]],'work_ball':groups['play'][:4],'work_kneel_down':groups['play'][4:6],'work_kneel':groups['play'][5:7],'work_inspect':groups['play'][5:7],'work_stand_up':[groups['play'][7],groups['play'][4],groups['play'][0]],'work_jump':groups['jump'][:5],'work_joy':groups['jump'][4:6]+[groups['jump'][7]],'work_rest':[groups['jump'][7]],'work_play':groups['play'][5:7],'gesture_think':groups['play'][5:7]})
used=sorted({i for v in clips.values() for i in v});unique=[];new_records=[];remap={};seen={}
for i in used:
 digest=hashlib.sha256(frames[i].tobytes()).hexdigest()
 if digest not in seen:seen[digest]=len(unique);unique.append(frames[i]);new_records.append(records[i])
 remap[i]=seen[digest]
frames=unique;records=new_records;clips={k:[remap[i] for i in v] for k,v in clips.items()}
atlas=Image.new('RGBA',(768,((len(frames)+7)//8)*96))
for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
atlas.save(G/'atlas.png')
lines=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/woodcutter_son545/game/atlas.png" id="1"]','']
for i in range(len(frames)):lines += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
lines+=['[resource]','metadata/rework_version = 54','metadata/son_version = 545','metadata/native_left_clips = PackedStringArray()','animations = [']
for name,ids in clips.items():
 loop=name not in ['work_ball','work_kneel_down','work_stand_up','work_jump','work_joy','work_rest']
 fps=7 if name.startswith('walk_') else 10 if name.startswith('run_') else 6 if name.startswith('work_') and name not in ['work_rest','work_kneel','work_play','work_inspect'] else 2.5
 lines+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in ids)+'],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}','},']
lines[-1]='}';lines+= [']',''];(G/'frames.tres').write_text('\n'.join(lines))
# Original portrait panels keep aspect ratio with nearest crop, no face stretching.
im=Image.open(S/'portrait.png').convert('RGB');(G/'portraits').mkdir(exist_ok=True)
sources['portrait']={'file':'portrait.png','sha256':hashlib.sha256((S/'portrait.png').read_bytes()).hexdigest(),'size':list(im.size)}
for i,name in enumerate(['neutral','joy','displeased','anxious']):
 panel=im.crop((round(i*im.width/4),0,round((i+1)*im.width/4),im.height));ratio=max(128/panel.width,192/panel.height)
 panel=panel.resize((round(panel.width*ratio),round(panel.height*ratio)),Image.Resampling.NEAREST);x=(panel.width-128)//2
 panel.crop((x,0,x+128,192)).save(G/'portraits'/(name+'.png'))
manifest={'id':'woodcutter_son','base':'08c9d04','target_height':TARGET,'canvas':[96,96],'pivot':[48,82],'sources':sources,'frames':records,'clips':clips,'limits':['Six selected gait drawings per direction, left mirrors right once','Front/rear conversation uses directed neutral breath poses','Generated drawings require artistic review in motion; unique hashes alone are not proof of anatomy']}
(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
catalog=json.loads((P/'data/visuals/animation_catalog.json').read_text());catalog['woodcutter_son']={'version':54,'correction_version':545,'frames':'res://assets/npc/woodcutter_son545/game/frames.tres','clips':{k:len(v) for k,v in clips.items()},'limits':manifest['limits'],'artistic_redesign_complete':False};(P/'data/visuals/animation_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
profile_path=P/'data/visuals/residents.json';profiles=json.loads(profile_path.read_text())
profiles['woodcutter_son']['portraits']={k:'res://assets/npc/woodcutter_son545/game/portraits/'+k+'.png' for k in ['neutral','joy','displeased','anxious']};profile_path.write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+'\n')
out=Image.new('RGB',(1152,12*192),(42,46,42));draw=ImageDraw.Draw(out)
for row,name in enumerate(['idle_down','walk_right','walk_down','walk_up','run_right','run_down','run_up','work_ball','work_kneel_down','work_stand_up','work_jump','talk']):
 for col,i in enumerate(clips[name]):
  cell=frames[i].resize((192,192),Image.Resampling.NEAREST);out.paste(cell,(col*192,row*192),cell)
 draw.text((4,row*192),name)
out.save('/workspace/work/stage545/native-poses.png')
print('Prepared',len(frames),'unique native poses;',len(clips),'clip names')
