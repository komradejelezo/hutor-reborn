"""Stage 5.3.2: original assets and gameplay stay unchanged; only alpha is cleaned."""
from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
R=Path(__file__).resolve().parents[2];P=R/'HutorReborn'
m=json.loads((P/'docs/stage532-invariants.json').read_text())
for name,h in m['protected'].items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==h, name+' changed'
for actor in ['woodcutter','innkeeper_wife']:
 src=np.array(Image.open(P/'assets/npc/stage43'/actor/'atlas.png').convert('RGBA'))
 dst=np.array(Image.open(P/'assets/npc/stage532'/(actor+'_atlas.png')).convert('RGBA'))
 assert src.shape==dst.shape and np.array_equal(src[:,:,:3],dst[:,:,:3]),actor+' RGB or dimensions changed'
 assert np.all(dst[:,:,3]<=src[:,:,3]) and np.any(dst[:,:,3]<src[:,:,3]),actor+' expected alpha-only removal'
 if actor=='innkeeper_wife':assert not dst[35:90,33,3].any(),'catalogue line remains'
 else:
  for index in [0,1]:
   a=dst[:96,index*96:(index+1)*96];rgb=a[:,:,:3].astype(int);y=np.arange(96)[:,None]
   assert not np.any((y>=73)&(rgb.max(2)-rgb.min(2)<38)&(rgb.min(2)>68)&(a[:,:,3]>0)),'light ground guide remains'
src=np.array(Image.open(P/'assets/environment/krivaya_sosna/surface_polish/common_house_ground.png'))
dst=np.array(Image.open(P/'assets/environment/visual_fixes_5_3/common_house.png'))
assert np.array_equal(src[:,:,:3],dst[:,:,:3]) and np.all(dst[:,:,3]<=src[:,:,3])
assert np.array_equal(src[:232,15:-15],dst[:232,15:-15]),'house core changed'
print('PASS:',len(m['protected']),'original images, audio, scenes, player, transitions, dialogues, schedules and time preserved')
print('PASS: two NPC derivatives change alpha only; guide line and light apron removed; house RGB/core unchanged')
