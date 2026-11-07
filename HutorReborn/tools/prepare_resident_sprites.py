"""Prepare archived NPC frames at game resolution with Nearest, not new drawings.
Original PNG bytes remain untouched. Honest one-frame idle fallbacks do not loop.
Authoring only: Pillow/numpy/scipy. Runtime uses small per-resident atlases.
"""
from pathlib import Path
import json
import hashlib
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--preview',type=Path,help='Optional review contact sheet outside the game assets')
options=parser.parse_args()
P=Path(__file__).resolve().parents[1]
SOURCE=P/'assets/npc/stage2'
OUT=P/'assets/npc/stage43'
OUT.mkdir(exist_ok=True)
CANVAS=(96,96)
PIVOT=(48,82)

def rgba(folder,file,count):
 return {'source':folder+'/'+file+'.png','boxes':[[i*793,0,(i+1)*793,1285] for i in range(count)],'rgba':True}
def reference(name,boxes):
 return {'source':'Npc/'+name+'.png','boxes':boxes,'rgba':False}
def ref_walk(name,old=False):
 bottom=506 if old else 522
 if name == 'Трактирщик':
  return {
   'walk_down':reference(name,[[472,382,550,518],[550,382,632,518]]),
   'walk_right':reference(name,[[786,382,868,518],[868,382,952,518]]),
   'walk_up':reference(name,[[968,382,1042,518],[1042,382,1111,518],[1111,382,1182,518]])}
 return {
  'walk_down':reference(name,[[475,370,548,bottom],[548,370,623,bottom]]),
  'walk_right':reference(name,[[785,370,858,bottom],[858,370,933,bottom]]),
  'walk_up':reference(name,[[935,370,1002,bottom],[1002,370,1065,bottom],[1065,370,1131,bottom]])}

definitions={
 'elder':{'height':48,'temporary':'Borrowed older-man study; an approved elder design is still needed','clips':ref_walk('Старик',True)},
 'innkeeper':{'height':50,'clips':{**ref_walk('Трактирщик'),'work_wipe':rgba('Трактирщик','Sprite-0007',4)}},
 'innkeeper_wife':{'height':47,'clips':{**ref_walk('Жена трактирщика'),'work_sweep':rgba('Жена трактирщика','Sprite-0009',3)}},
 'woodcutter':{'height':48,'clips':{'walk_down':rgba('Дровосек','Sprite-0006',2),'walk_up':rgba('Дровосек','Sprite-0005',4),'walk_right':rgba('Дровосек','Sprite-0011',3),'work_chop':rgba('Дровосек','Sprite-00101',6)}},
 'woodcutter_wife':{'height':46,'clips':{'walk_down':rgba('Жена дровосека','Sprite-0002',2),'walk_up':rgba('Жена дровосека','Sprite-0003',2),'walk_right':rgba('Жена дровосека','Sprite-0004',4),'work_sweep':rgba('Жена дровосека','Sprite-0001',2)}},
 'woodcutter_son':{'height':33,'clips':{'walk_down':rgba('Сын дровосека','Sprite-0001',2),'walk_up':rgba('Сын дровосека','Sprite-0002',2),'walk_right':rgba('Сын дровосека','Sprite-0007',2),'work_play':rgba('Сын дровосека','Sprite-0010',6)}},
 'herbalist':{'height':47,'clips':{'walk_down':rgba('Марта','Sprite-0015',2),'walk_up':rgba('Марта','Sprite-0016',2),'walk_right':rgba('Марта','Sprite-0014',3),'work_gather':rgba('Марта','Sprite-0005',4)}},
 'herbalist_brother':{'height':49,'clips':{'walk_down':rgba('Ганс','Sprite-0008',2),'walk_up':rgba('Ганс','Sprite-0010',2),'walk_right':rgba('Ганс','Sprite-0004',5),'work_chop':rgba('Ганс','Sprite-0009',5)}},
 'old_man':{'height':44,'clips':{'walk_down':rgba('Страрик','Sprite-0005',2),'walk_up':rgba('Страрик','Sprite-0004',2),'walk_right':rgba('Страрик','Sprite-001',2),'work_smoke':rgba('Страрик','Sprite-0013',3)}},
}

def extract(clip,box):
 image=Image.open(SOURCE/clip['source']).convert('RGBA').crop(box)
 data=np.array(image)
 if not clip['rgba']:
  a=data[:,:,:3].astype(np.int16)
  background=(a.max(2)<66)&(a[:,:,0]<=a[:,:,1]+7)&(a[:,:,0]<=a[:,:,2]+10)
  seeds=np.zeros(background.shape,bool)
  seeds[0]=background[0];seeds[-1]=background[-1];seeds[:,0]|=background[:,0];seeds[:,-1]|=background[:,-1]
  keep=~ndi.binary_propagation(seeds,mask=background)
  labels,_=ndi.label(keep,np.ones((3,3)))
  keep &= np.bincount(labels.ravel())[labels]>=5
  keep=ndi.binary_fill_holes(keep)
  # The reviewed boxes exclude catalogue labels and columns; keep no card edges.
  keep[0]=False;keep[-1]=False;keep[:,0]=False;keep[:,-1]=False
  data[:,:,3]=keep*255
 else:
  # Some original movement sheets contain non-character white/grey ground guides.
  a=data[:,:,:3].astype(int);y=np.arange(data.shape[0])[:,None]
  guides=(y>data.shape[0]*.9)&(np.abs(a[:,:,0]-a[:,:,1])<12)&((a.max(2)-a.min(2))<40)&(a.max(2)>90)
  data[guides,3]=0
 return Image.fromarray(data)

manifest={'canvas':CANVAS,'pivot':PIVOT,'method':'original crops and alpha cleanup; Nearest to game resolution; no painting','residents':{}}
for npc,definition in definitions.items():
 target=OUT/npc;target.mkdir(exist_ok=True)
 clips={};sources={};raw_frames={}
 for name,clip in definition['clips'].items():
  raw_frames[name]=[extract(clip,box) for box in clip['boxes']]
  src=SOURCE/clip['source'];sources[clip['source']]=hashlib.sha256(src.read_bytes()).hexdigest()
 # Walk and work may come from different source formats; each family keeps one scale.
 reference_height={}
 for family in [False,True]:
  candidates=[im.getbbox()[3]-im.getbbox()[1] for name,items in raw_frames.items() if definition['clips'][name]['rgba']==family and name.startswith('walk') for im in items if im.getbbox()]
  if not candidates:
   candidates=[im.getbbox()[3]-im.getbbox()[1] for name,items in raw_frames.items() if definition['clips'][name]['rgba']==family for im in items if im.getbbox()]
  if candidates:reference_height[family]=float(np.median(candidates))
 records=[];images=[]
 for name,frames in raw_frames.items():
  clip=definition['clips'][name];ratio=definition['height']/reference_height[clip['rgba']]
  anchors=[]
  for image in frames:
   arr=np.asarray(image);alpha=arr[:,:,3]>32;ys,xs=np.nonzero(alpha)
   assert len(xs)>0,(npc,name)
   # Torso centre excludes most outstretched arms and held tools.
   top,bottom=ys.min(),ys.max();band=(ys>top+(bottom-top)*.30)&(ys<top+(bottom-top)*.65)
   cx=float(np.median(xs[band])) if band.any() else float(np.median(xs))
   lower=alpha.copy();lower[:int(top+(bottom-top)*.70)]=False
   lower[:,:max(0,int(cx-(180 if clip['rgba'] else 18)))]=False
   lower[:,min(image.width,int(cx+(180 if clip['rgba'] else 18))):]=False
   yfoot=int(np.nonzero(lower)[0].max()) if lower.any() else int(bottom)
   anchors.append([cx,yfoot])
  # Source strips share a foot plane within a clip, preserving original gait bobbing.
  foot=np.median(np.array(anchors),axis=0)
  indices=[]
  for index,image in enumerate(frames):
   size=(max(1,round(image.width*ratio)),max(1,round(image.height*ratio)))
   reduced=image.resize(size,Image.Resampling.NEAREST)
   offset=(PIVOT[0]-round(foot[0]*ratio),PIVOT[1]-round(foot[1]*ratio))
   frame=Image.new('RGBA',CANVAS);frame.paste(reduced,offset)
   assert frame.getbbox(),(npc,name,index)
   indices.append(len(images));images.append(frame)
   records.append({'clip':name,'index':index,'source':clip['source'],'box':clip['boxes'][index],'source_foot':foot.tolist(),'scale':ratio,'resized':size,'offset':offset})
  clips[name]=indices
 for direction in ['down','up','right']:
  clips['idle_'+direction]=[clips['walk_'+direction][0]]
 # Left uses the right frames with runtime flip_h; no fabricated left artwork.
 clips['walk_left']=clips['walk_right'];clips['idle_left']=clips['idle_right']
 cols=8;rows=(len(images)+cols-1)//cols
 atlas=Image.new('RGBA',(cols*96,rows*96))
 for i,frame in enumerate(images):atlas.paste(frame,(i%cols*96,i//cols*96))
 atlas.save(target/'atlas.png')
 text=['[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/npc/stage43/'+npc+'/atlas.png" id="1"]','']
 for i in range(len(images)):
  text+=['[sub_resource type="AtlasTexture" id="Frame_'+str(i)+'"]','atlas = ExtResource("1")',f'region = Rect2({i%cols*96}, {i//cols*96}, 96, 96)','filter_clip = true','']
 text+=['[resource]','animations = [']
 for name,indices in clips.items():
  text+=['{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("Frame_'+str(i)+'")}' for i in indices)+'],',f'"loop": {str(len(indices)>1).lower()},',f'"name": &"{name}",',f'"speed": {6.0 if npc=="old_man" else 8.0}', '},']
 text[-1]='}';text+= [']',''];(target/'frames.tres').write_text('\n'.join(text),encoding='utf-8')
 manifest['residents'][npc]={'height':definition['height'],'temporary':definition.get('temporary',''),'sources':sources,'frames':records,'clips':clips,'missing_art':['animated_idle_down','animated_idle_up','animated_idle_right','animated_idle_left','neutral_portrait','joy_portrait','displeased_portrait','anxious_portrait']}
(OUT/'sprite_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),12)
preview=Image.new('RGB',(864,9*126),(31,34,29));draw=ImageDraw.Draw(preview)
for row,(npc,data) in enumerate(manifest['residents'].items()):
 draw.text((8,row*126+3),npc,font=font,fill='#e2d2af')
 atlas=Image.open(OUT/npc/'atlas.png')
 for col,direction in enumerate(['down','up','right']):
  for n,i in enumerate(data['clips']['walk_'+direction]):
   frame=atlas.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));preview.paste(frame,(col*280+n*72,row*126+22),frame)
if options.preview:
 options.preview.parent.mkdir(parents=True,exist_ok=True)
 preview.save(options.preview)
print('Prepared nine small resident atlases; real walk/action frames, explicitly static idle fallbacks')
