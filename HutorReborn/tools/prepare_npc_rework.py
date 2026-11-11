"""Stage 5.4: reviewed artwork crops, not labels pretending to be production sheets.
Keeps the supplied references separate. Authoring only: Pillow/numpy/scipy.
No previous resource, character ID, collision or schedule is removed.
"""
from pathlib import Path
import json,hashlib,argparse
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage as ndi
P=Path(__file__).resolve().parents[1];B=P/'assets/npc/stage54';O=B/'game';O.mkdir(exist_ok=True)
IDS={'elder':'village_headman','innkeeper':'tavern_keeper','innkeeper_wife':'tavern_keeper_wife','woodcutter':'woodcutter','woodcutter_wife':'woodcutter_wife','woodcutter_son':'woodcutter_son','herbalist':'herbalist','herbalist_brother':'herbalist_brother','old_man':'old_man_pipe'}
HEIGHT={'elder':48,'innkeeper':50,'innkeeper_wife':47,'woodcutter':48,'woodcutter_wife':46,'woodcutter_son':33,'herbalist':47,'herbalist_brother':49,'old_man':44}
def lane(x0,y0,x1,y1,n):return [[round(x0+(x1-x0)*i/n),y0,round(x0+(x1-x0)*(i+1)/n),y1] for i in range(n)]
def extract(image,box,alpha=False,cut_bottom=None):
 a=np.array(image.crop(box).convert('RGBA'))
 if alpha:keep=a[:,:,3]>128
 else:
  rgb=a[:,:,:3].astype(int);bg=((rgb.max(2)<48)&(rgb.max(2)-rgb.min(2)<15))|((rgb.max(2)<60)&(np.abs(rgb[:,:,0]-rgb[:,:,1])<6)&(np.abs(rgb[:,:,1]-rgb[:,:,2])<6))
  seeds=np.zeros(bg.shape,bool);seeds[0]=bg[0];seeds[-1]=bg[-1];seeds[:,0]|=bg[:,0];seeds[:,-1]|=bg[:,-1]
  keep=~ndi.binary_propagation(seeds,mask=bg)
  labels,_=ndi.label(keep,np.ones((3,3)));sizes=np.bincount(labels.ravel());sizes[0]=0
  for label,box in enumerate(ndi.find_objects(labels),1):
   if box:
    bh=box[0].stop-box[0].start;bw=box[1].stop-box[1].start
    if (bw<=12 and bh>max(12,bw*5)) or (bh<=12 and bw>max(14,bh*5)):keep[labels==label]=False
  keep &= sizes[labels]>=max(5,sizes.max()*.018)
  keep=ndi.binary_fill_holes(keep)
 if cut_bottom is not None:keep[cut_bottom:]=False
 keep[0]=False;keep[-1]=False;keep[:,0]=False;keep[:,-1]=False
 a[:,:,3]=keep*255;return Image.fromarray(a)
def anchor(im):
 a=np.array(im)[:,:,3]>0;ys,xs=np.nonzero(a);top,bottom=int(ys.min()),int(ys.max())
 band=(ys>top+(bottom-top)*.28)&(ys<top+(bottom-top)*.6);cx=float(np.median(xs[band]))
 low=a.copy();low[:int(top+(bottom-top)*.7)]=False
 low[:,:max(0,int(cx-22))]=False;low[:,min(a.shape[1],int(cx+23)):]=False
 foot=int(np.nonzero(low)[0].max()) if low.any() else bottom
 return cx,foot,top,bottom
# Manual row boundaries exclude all labels, frames and separators.
ROWS={
 'woodcutter':[(215,9,1224,121),(215,136,1224,247),(215,261,1224,369),(215,386,1224,497)],
 'woodcutter_wife':[(660,25,1520,139),(660,156,1520,271),(660,288,1520,401),(660,420,1520,533)],
 'woodcutter_son':[(642,20,1518,106),(642,118,1518,203),(642,215,1518,295),(642,310,1518,385)],
 'innkeeper_wife':[(652,22,1518,120),(652,133,1518,218),(652,231,1518,314),(652,328,1518,411)],
 'herbalist':[(650,15,1518,109),(650,114,1518,204),(650,210,1518,297),(650,303,1518,398)],
 'innkeeper':[(652,18,1518,111),(652,122,1518,208),(652,222,1518,307),(652,322,1518,406)],
}
DEFAULT=[(650,18,1518,110),(650,122,1518,208),(650,219,1518,299),(650,314,1518,399)]
# clip: bounds, actual count, source body type, optional discarded table pixels.
WORK={
 'woodcutter':{'work_chop':((235,635,1222,772),6,'full',None),'work_saw':((235,800,1222,927),6,'full',None)},
 'woodcutter_wife':{'work_laundry':((560,750,1516,901),6,'full',None)},
 'woodcutter_son':{'work_play':((329,808,616,888),4,'full',None),'work_kneel':((1250,810,1518,888),4,'full',None),'work_ball':((650,813,901,889),4,'full',None)},
 'innkeeper':{'work_wipe':((340,668,890,768),6,'counter',76),'work_serve':((940,662,1510,768),6,'counter',80),'work_tray':((937,850,1511,966),6,'full',None)},
 'innkeeper_wife':{'work_wipe':((349,656,892,776),6,'counter',81),'work_set_table':((931,657,1515,776),6,'full',None),'work_tray':((348,849,891,970),6,'full',None),'work_cook':((936,849,1515,970),6,'counter',99)},
 'elder':{'work_read':((342,659,893,763),6,'desk',None),'work_write':((931,664,1517,765),6,'desk',79),'work_gesture':((342,839,893,952),6,'desk',None)},
 'old_man':{'work_smoke':((342,660,895,761),6,'full',None),'work_sit':((932,650,1516,762),6,'seat',None),'work_carve':((342,846,895,962),6,'seat',None),'work_story':((938,838,1515,961),6,'full',None)},
 'herbalist':{'work_gather':((337,647,895,757),6,'plants',None),'work_grind':((936,650,1514,762),6,'desk',None),'work_dry':((941,841,1235,973),3,'full',None),'work_pack':((1242,855,1515,971),3,'plants',None)},
 'herbalist_brother':{'work_chop':((342,631,895,761),6,'full',None),'work_mend':((941,656,1515,761),6,'seat',None),'work_gather':((342,835,893,953),6,'full',None)},
}
manifest={'version':54,'canvas':[96,96],'pivot':[48,82],'source_kind':'approved decorated reference boards; reviewed crops, not ready technical sheets','residents':{}}
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),12)
contact=Image.new('RGB',(1180,9*132),(39,43,38));draw=ImageDraw.Draw(contact)
for row,(id,file) in enumerate(IDS.items()):
 out=O/id;out.mkdir(exist_ok=True);source=B/'references'/(file+'.png');im=Image.open(source).convert('RGBA')
 raw={};spec={};clips={};frames=[];records=[]
 for direction,rect in zip(['down','up','left','right'],ROWS.get(id,DEFAULT)):
  name='walk_'+direction;rect=(rect[0],rect[1]-10,rect[2],rect[3]+(0 if direction=="right" else 2));boxes=lane(*rect,8);boxes[-1][2]-=10;raw[name]=[extract(im,b) for b in boxes];spec[name]={'boxes':boxes,'body':'full'}
 if id=='woodcutter':idle=(235,513,721,622);talk=(875,512,1224,624)
 elif id=='woodcutter_wife':idle=(508,573,899,709);talk=(1093,573,1515,709)
 elif id=='woodcutter_son':idle=(499,535,898,642);talk=(1098,535,1518,642)
 elif id=='innkeeper_wife':idle=(580,437,899,549);talk=(1090,437,1518,549)
 elif id=='innkeeper':idle=(585,436,948,546);talk=(1115,436,1518,546)
 elif id=='herbalist_brother':idle=(585,423,938,539);talk=(1104,424,1518,538)
 elif id=='herbalist':idle=(585,419,938,535);talk=(1104,419,1518,535)
 else:idle=(585,424,938,535);talk=(1104,424,1518,535)
 for name,rect in [('idle_down',idle),('talk',talk)]:
  count=3 if id=='innkeeper_wife' and name=='idle_down' else 4
  boxes=lane(*rect,count)
  if name=='idle_down' and id in ['innkeeper_wife','herbalist']:boxes[-1][2]-=16
  raw[name]=[extract(im,b) for b in boxes];spec[name]={'boxes':boxes,'body':'full'}
 for name,(rect,count,body,cut) in WORK[id].items():
  boxes=lane(*rect,count);work_im=im.copy()
  if id=='herbalist_brother' and name=='work_chop':ImageDraw.Draw(work_im).rectangle((342,631,533,655),fill=(0,0,0,255))
  raw[name]=[extract(work_im,b,cut_bottom=cut) for b in boxes];spec[name]={'boxes':boxes,'body':body}
 if id=='woodcutter_son':
  rect=(626,421,1516,496);boxes=lane(*rect,8);raw['run_right']=[extract(im,b) for b in boxes];spec['run_right']={'boxes':boxes,'body':'full'}
 walk_height=np.median([anchor(f)[3]-anchor(f)[2]+1 for n,items in raw.items() if n.startswith('walk_') for f in items]);walk_ratio=HEIGHT[id]/walk_height
 idle_height=np.median([anchor(f)[3]-anchor(f)[2]+1 for f in raw['idle_down']]);idle_ratio=HEIGHT[id]/idle_height
 for name,items in raw.items():
  ratio=HEIGHT[id]/np.median([anchor(f)[3]-anchor(f)[2]+1 for f in items]) if name.startswith(('walk_','run_')) else idle_ratio
  if id=='woodcutter_wife' and name.startswith('work_'):ratio*=.85
  if id=='herbalist' and name=='work_gather':ratio*=.92
  stats=[anchor(f) for f in items];foot=float(np.median([s[1] for s in stats]))
  if spec[name]['body'] in ['counter','desk']:foot=float(np.median([s[2] for s in stats]))+HEIGHT[id]/ratio
  indices=[]
  for n,(f,stat) in enumerate(zip(items,stats)):
   small=f.resize((max(1,round(f.width*ratio)),max(1,round(f.height*ratio))),Image.Resampling.NEAREST)
   canvas=Image.new('RGBA',(96,96));cx=stat[0];offset=[48-round(cx*ratio),82-round(foot*ratio)];canvas.paste(small,offset)
   if not canvas.getbbox():raise ValueError((id,name,n))
   indices.append(len(frames));frames.append(canvas);records.append({'clip':name,'index':n,'box':spec[name]['boxes'][n],'body':spec[name]['body'],'scale':ratio,'offset':offset})
  clips[name]=indices
 extra=[]
 if id=='woodcutter_son':extra=[('child_run_vertical.png',0,'run_down'),('child_run_vertical.png',1,'run_up')]
 if id=='woodcutter_wife':extra=[('sweeping_women.png',0,'work_sweep'),('read_and_cook.png',1,'work_cook')]
 if id=='innkeeper_wife':extra=[('sweeping_women.png',1,'work_sweep')]
 if id=='elder':extra=[('read_and_cook.png',0,'work_read_full')]
 for filename,rr,clip in extra:
  genpath=B/'generated_source'/filename;gen=Image.open(genpath).convert('RGBA');gw,gh=gen.size
  items=[extract(gen,[round(i*gw/4),round(rr*gh/2),round((i+1)*gw/4),round((rr+1)*gh/2)],alpha=True) for i in range(4)]
  stats=[anchor(f) for f in items];ratio=HEIGHT[id]/max(t[3]-t[2]+1 for t in stats);foot=max(t[1] for t in stats);indices=[]
  for n,(f,stat) in enumerate(zip(items,stats)):
   small=f.resize((max(1,round(f.width*ratio)),max(1,round(f.height*ratio))),Image.Resampling.NEAREST);canvas=Image.new('RGBA',(96,96));offset=[48-round(stat[0]*ratio),82-round(foot*ratio)];canvas.paste(small,offset);indices.append(len(frames));frames.append(canvas);records.append({'clip':clip,'index':n,'source':'generated_source/'+filename,'body':'full','scale':ratio,'offset':offset})
  clips[clip]=indices
 if id=='woodcutter_son':clips['run_left']=clips['run_right']
 for direction in ['up','left','right']:
  candidates=clips['walk_'+direction]
  # A genuine directional pose, not fabricated directional blink/turn art.
  clips['idle_'+direction]=[candidates[2]]
 for direction in ['down','up','left','right']:clips['turn_'+direction]=[clips['idle_'+direction][0]]
 clips['talk_down']=clips['talk'];clips['talk_right']=clips['talk'];clips['talk_left']=clips['talk'];clips['talk_up']=clips['idle_up']
 # Existing names remain loadable; activity presenter chooses only approved bound work.
 aliases={'work_inspect':'idle_down','work_table':'work_grind','work_think':'work_story','gesture_read':'work_read','gesture_think':'idle_down'}
 for a,b in aliases.items():
  if b in clips and a not in clips:clips[a]=clips[b]
 atlas=Image.new('RGBA',(8*96,((len(frames)+7)//8)*96))
 for i,f in enumerate(frames):atlas.paste(f,(i%8*96,i//8*96))
 atlas.save(out/'atlas.png')
 text=['[gd_resource type="SpriteFrames" format=3]','',f'[ext_resource type="Texture2D" path="res://assets/npc/stage54/game/{id}/atlas.png" id="1"]','']
 for i in range(len(frames)):
  text += [f'[sub_resource type="AtlasTexture" id="F{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*96}, {i//8*96}, 96, 96)','filter_clip = true','']
 text += ['[resource]','metadata/rework_version = 54','metadata/native_left_clips = PackedStringArray("walk_left", "idle_left", "turn_left")','animations = [']
 for name,indices in clips.items():
  speeds={'elder':30,'innkeeper':28,'innkeeper_wife':34,'woodcutter':36,'woodcutter_wife':32,'woodcutter_son':77.5,'herbalist':29,'herbalist_brother':37,'old_man':18}
  gait_fps=round(min(12,max(4,speeds[id]*8/(HEIGHT[id]*.75))),2)
  fps=(16 if name in ['run_left','run_right'] else 8) if name.startswith('run_') else gait_fps if name.startswith('walk_') else 3 if name.startswith('idle_') else 4.5 if name.startswith('talk') else 4
  text += ['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("F'+str(i)+'")}' for i in indices)+'],',f'"loop": {str(len(indices)>1).lower()},',f'"name": &"{name}",',f'"speed": {fps}', '},']
 text[-1]='}';text+= [']',''];(out/'frames.tres').write_text('\n'.join(text))
 portrait_dir=out/'portraits';portrait_dir.mkdir(exist_ok=True)
 emotion_map={'neutral':(0,0),'joy':(2,0),'displeased':(1,1),'anxious':(1,0)}
 if id in ['herbalist','herbalist_brother','woodcutter_wife']:emotion_map={'neutral':(0,0),'joy':(2,1),'displeased':(1,1),'anxious':(1,0)}
 if id=='woodcutter_son':emotion_map={'neutral':(0,0),'joy':(2,0),'displeased':(2,1),'anxious':(1,0)}
 if id=='woodcutter':
  for emotion,(rr,cc) in emotion_map.items():
   x=1271+cc*135;y=435+rr*153;box=(x+22,y,x+98,y+114);crop=im.crop(box).resize((128,192),Image.Resampling.NEAREST);crop.save(portrait_dir/(emotion+'.png'))
 else:
  for emotion,(rr,cc) in emotion_map.items():
   x=18+cc*145;y=400+rr*163;box=(x+27,y,x+91,y+96);crop=im.crop(box).resize((128,192),Image.Resampling.NEAREST);crop.save(portrait_dir/(emotion+'.png'))
 manifest['residents'][id]={'reference':str(source.relative_to(P)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'target_height':HEIGHT[id],'clips':clips,'frames':records,'work_source':{**{n:r['body'] for n,r in spec.items() if n.startswith('work_')},**{f['clip']:'generated_full_body' for f in records if 'source' in f}},'limits':['up/side idle and up talk use static directional poses','8 reference walk images are not proof of eight anatomically perfect gait phases']}
 y=row*132;draw.text((4,y+3),id,font=font,fill='white')
 for col,name in enumerate(['walk_down','walk_up','walk_left','walk_right','idle_down','talk']):
  frame=frames[clips[name][0]];contact.paste(frame,(150+col*150,y+22),frame);draw.text((150+col*150,y+4),name,font=font,fill='#d6c7a1')
(B/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--preview',type=Path);args=parser.parse_args()
if args.preview:contact.save(args.preview)
print('Prepared',len(IDS),'reference-based residents; compare temporal playback before accepting frames')

props=O/'props';props.mkdir(exist_ok=True)
for name,source,box in [('wash_tub','woodcutter_wife',(620,854,694,896)),('toy_ball','woodcutter_son',(685,863,705,886))]:
 image=Image.open(B/'references'/(source+'.png')).convert('RGBA');extract(image,box).save(props/(name+'.png'))
