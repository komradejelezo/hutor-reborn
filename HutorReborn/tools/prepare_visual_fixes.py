"""Focused 5.3.2 derivatives: retained RGB is always original; never paint NPC art.
Authoring dependencies: Pillow, numpy, scipy. Original/corrected files stay separate.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
P=Path(__file__).resolve().parents[1]
O=P/'assets/environment/visual_fixes_5_3';O.mkdir(parents=True,exist_ok=True)
N=P/'assets/npc/stage532';N.mkdir(parents=True,exist_ok=True)
records=[]
def save(im,path,source,method):
 im.save(path)
 records.append({'output':str(path.relative_to(P)),'source':str(source.relative_to(P)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'method':method})
for actor in ['innkeeper_wife','woodcutter']:
 source=P/'assets/npc/stage43'/actor/'atlas.png';a=np.array(Image.open(source).convert('RGBA'));original=a.copy()
 for index in ([0] if actor=='innkeeper_wife' else [0,1]):
  frame=a[0:96,index*96:(index+1)*96];alpha=frame[:,:,3]>0
  if actor=='innkeeper_wife':
   labels,count=ndi.label(alpha,np.ones((3,3)))
   for label,box in enumerate(ndi.find_objects(labels),1):
    if box and box[1].stop-box[1].start<=2 and box[0].stop-box[0].start>=20 and box[1].start<36:frame[labels==label,3]=0
  else:
   rgb=frame[:,:,:3].astype(int);y=np.arange(96)[:,None]
   guide=(y>=73)&(rgb.max(2)-rgb.min(2)<38)&(rgb.min(2)>68)
   frame[guide,3]=0
 assert np.array_equal(a[:,:,:3],original[:,:,:3]);assert np.count_nonzero(a[:,:,3]!=original[:,:,3])>0
 save(Image.fromarray(a),N/(actor+'_atlas.png'),source,'alpha cleanup only; all RGB, dimensions, frame positions and foot anchors preserved')
source=P/'assets/environment/krivaya_sosna/surface_polish/common_house_ground.png'
a=np.array(Image.open(source).convert('RGBA'));h,w=a.shape[:2];y,x=np.mgrid[:h,:w]
# Only the apron/outer edge fades. Architecture and steps in the core are protected.
threshold=((x//2*37+y//2*71)%101)/101
edge=np.minimum(x,w-1-x)/15.0
bottom=(h-1-y)/56.0
weight=np.minimum(np.clip(edge,0,1),np.clip(bottom,0,1))
periphery=(y>=232)|((x<15)|(x>w-16))
a[periphery&(weight<=threshold),3]=0
save(Image.fromarray(a),O/'common_house.png',source,'binary irregular alpha on apron only; roof/walls/stairs core and retained RGB unchanged')
for kind in ['wall','wall_old']:
 source=P/'assets/interiors/stage44'/(kind+'.png');im=Image.open(source).convert('RGBA')
 atlas=Image.new('RGBA',(96,96));atlas.paste(im,(0,0))
 left=im.transpose(Image.Transpose.ROTATE_90);right=im.transpose(Image.Transpose.ROTATE_270)
 # Continuous native board grain along the side; only endpoint rows reuse source pixels.
 for tile in [left,right]:
  tile.paste(tile.crop((0,1,32,2)),(0,31))
 atlas.paste(left,(32,0));atlas.paste(right,(64,0))
 # Native-pixel corner mitres avoid a horizontal cap abruptly entering side grain.
 for col,side in enumerate([left,right,im]):
  corner=np.array(side);top=np.array(im)
  yy,xx=np.mgrid[:32,:32];mask=(yy<xx) if col==0 else (yy<31-xx)
  corner[mask]=top[mask];cap=Image.fromarray(corner);atlas.paste(cap,(col*32,32));atlas.paste(cap.transpose(Image.Transpose.FLIP_TOP_BOTTOM),(col*32,64))
 save(atlas,O/(kind+'_atlas.png'),source,'native 32px top/side/corner tiles; rotations and copied native pixels only')
source=P/'assets/environment/smoke.png';a=np.array(Image.open(source).convert('RGBA'));a[:,:,3]=np.minimum(a[:,:,3].astype(float)*2.4,170).astype('uint8')
save(Image.fromarray(a),O/'chimney_smoke.png',source,'same 16px texture and RGB; alpha x2.4 for chimney only, no filtering')
(O/'provenance.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('Prepared',len(records),'focused derivatives; all originals retained')
