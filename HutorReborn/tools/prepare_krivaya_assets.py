"""Extract the archived original art without resampling RGB pixels.
Requires Pillow, numpy and scipy for authoring only. Originals are located through
assets/stage2_catalog.json. Crops, native pixels, alpha masks and terrain edges are
reproducible; the map is separately authored by build_krivaya_sosna.gd.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from scipy import ndimage as ndi
import json,shutil,hashlib,random
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/environment/krivaya_sosna'
rows=json.loads((ROOT/'assets/stage2_catalog.json').read_text())
class OriginalLibrary:
 def __init__(self, catalog):
  self.files={item['file']: ROOT/item['project_path'] for item in catalog}
 def __truediv__(self, name):
  return self.files[str(name)]
RAW=OriginalLibrary(rows)
catalog=[]
for row in rows:
 name=row['file'];src=RAW/name
 if name.startswith('Шаги/'):
  dst=ROOT/'assets/characters/hans/source'/Path(name).name
  assert dst.read_bytes()==src.read_bytes()
 elif '/' in name:
  dst=ROOT/'assets/npc/stage2'/name
 else:dst=BASE/'source'/name
 dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():shutil.copy2(src,dst)
 row['project_path']=str(dst.relative_to(ROOT));catalog.append(row)
# RGB reference sheets contain textured dark backdrops, not real transparent sprites.
# Mask only the inferred backdrop, retain original RGB values for every retained pixel.
def dark_mask(im,limit=34):
 a=np.asarray(im.convert('RGB')).astype(np.int16)
 high=a.max(2);low=a.min(2)
 # Neutral dark backdrop and its subtle green cast. Brown wood/olive leaves survive.
 background=(high<38)&((a[:,:,0]-a[:,:,2])<8)&(np.abs(a[:,:,0]-a[:,:,1])<7)
 seed=np.zeros(background.shape,bool);seed[0,:]=background[0,:];seed[-1,:]=background[-1,:];seed[:,0]|=background[:,0];seed[:,-1]|=background[:,-1]
 outside=ndi.binary_propagation(seed,mask=background)
 keep=~outside
 # Drop isolated backdrop specks, while preserving small foliage clusters.
 labels,n=ndi.label(keep);counts=np.bincount(labels.ravel());keep &= counts[labels]>=3
 return keep

def crop(name,source,box,scale=1.0,pivot=None,mode='dark',polygon=None,clear=()):
 im=Image.open(RAW/source).convert('RGBA').crop(box)
 if mode=='dark':
  keep=dark_mask(im)
  cores={
   'elder_house':[(12,115),(44,20),(86,20),(86,2),(119,2),(120,20),(205,20),(232,100),(221,194),(18,193)],
   'miller_house':[(10,105),(33,20),(145,20),(145,1),(168,1),(168,22),(210,22),(235,102),(216,191),(23,192)],
   'carpenter_house':[(14,106),(43,27),(166,27),(207,106),(198,188),(25,188)],
   'herbalist_house':[(26,117),(80,26),(113,26),(113,6),(146,6),(146,23),(194,33),(271,113),(266,189),(45,193)],
   'well':[(12,43),(16,28),(52,28),(61,44),(59,73),(9,72)],
  }
  if name in cores:
   protect=Image.new('1',im.size);ImageDraw.Draw(protect).polygon(cores[name],fill=1)
   keep |= np.array(protect)

  a=np.array(im)
  if name=='fence_v':
   rgb=a[:,:,:3].astype(int);background=(rgb.max(2)<52)&((rgb.max(2)-rgb.min(2))<23)
   keep &= ~background
   keep=ndi.binary_fill_holes(ndi.binary_closing(keep,iterations=1))
  if name.endswith('_house'):
   rgb=a[:,:,:3].astype(int)
   backdrop=(rgb[:,:,2]>=rgb[:,:,0])&(rgb[:,:,1]>=rgb[:,:,0])&(rgb.max(2)<57)
   keep &= ~backdrop
   keep=ndi.binary_fill_holes(keep)
  a[:,:,3]=np.where(keep,255,0);im=Image.fromarray(a)
 if polygon:
  if name.startswith('pine_'):
   a=np.array(im);rgb=a[:,:,:3].astype(int)
   leaves=(rgb[:,:,1]>rgb[:,:,0]+1)&(rgb[:,:,1]>rgb[:,:,2]+6)
   leaves=ndi.binary_fill_holes(ndi.binary_closing(leaves,iterations=3))
   leaves[120:180,49:72]=True
   a[:,:,3]=np.where(leaves,255,0);im=Image.fromarray(a)
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(polygon,fill=255)
  alpha=np.minimum(np.array(im.getchannel('A')),np.array(mask));a=np.array(im);a[:,:,3]=alpha;im=Image.fromarray(a)
 if clear:
  a=np.array(im)
  for x0,y0,x1,y1 in clear:a[y0:y1,x0:x1,3]=0
  im=Image.fromarray(a)
 im.save(BASE/'objects'/f'{name}.png')
 item={'name':name,'source':source,'box':box,'mode':mode,'scale':scale,'pivot':pivot or [im.width/2,im.height-12], 'polygon':polygon,'clear':clear,'size':im.size}
 objects.append(item)
objects=[]
crop('elder_house','Тайл избы.png',(22,778,256,1000),1.15,pivot=[122,202])
crop('miller_house','Тайл избы.png',(269,778,504,1000),1.15,pivot=[122,202])
crop('carpenter_house','Тайл избы.png',(510,780,738,1000),1.15,pivot=[115,202])
crop('common_house','трактир.png',(267,85,500,390),1.15,pivot=[119,258])
crop('herbalist_house','Тайл избы.png',(984,780,1284,1000),1.1,pivot=[152,203])
crop('crooked_pine','кривая сосна.png',(18,25,647,746),.64,pivot=[246,642],clear=[(0,0,211,63)])
crop('mixed_tree','кривая сосна.png',(653,104,898,393),.85,pivot=[124,250])
# Native fir silhouettes extracted from their illustrated cards. The non-transparent
# ground around these is excluded by an explicitly reviewed silhouette polygon.
for i,x in enumerate([24,149,274,404]):
 crop('pine_'+str(i),'Тайл природа.png',(x,129,x+118,315),1.55,pivot=[58,173],mode='opaque',polygon=[(57,2),(67,19),(71,39),(83,66),(82,77),(96,106),(94,114),(108,145),(101,155),(75,156),(73,179),(45,179),(45,157),(12,157),(18,142),(16,131),(28,110),(27,102),(38,78),(37,67),(46,47),(46,27)])
# Shrubs, stumps, rocks and native grass flowers; bright source pixels unchanged.
crop('shrub','кривая сосна.png',(840,985,985,1098),.6)
crop('grass','Тайл земля, база.png',(142,1026,199,1086),.65)
crop('flowers','Тайл декор.png',(768,766,815,827),.65)
crop('rock','Тайл декор.png',(81,773,133,829),.9)
crop('stump','Тайл декор.png',(230,481,275,537),.9)
crop('logs','Тайл декор.png',(88,475,153,541),1.0)
crop('wood_store','Тайл декор.png',(328,578,444,675),1.0)
crop('barrel','Тайл декор.png',(927,148,988,214),.6)
crop('crate','Тайл декор.png',(993,152,1046,213),.6)
crop('vegetable_box','Тайл декор.png',(1216,152,1268,213),.65)
crop('cart','Тайл декор.png',(1300,149,1389,241),1.0)
crop('lantern','Тайл декор.png',(1130,469,1155,554),.7)
crop('hanging_lantern','Тайл декор.png',(1310,467,1381,548),.7)
crop('sign','Тайл декор.png',(1132,645,1217,729),.8)
crop('scarecrow','Тайл декор.png',(600,922,652,993),1.0)
crop('pumpkins','Тайл декор.png',(17,940,72,997),.75)
crop('bench','трактир.png',(906,927,997,977),.8)
crop('warm_window','Пустой дом.png',(1403,134,1472,222),.4,pivot=[34,44])
crop('well','Тайл избы.png',(812,482,885,567),1.0,pivot=[36,77])
crop('fence_h','заборы горизонт.png',(36,472,489,699),.25,pivot=[226,161],mode='rgba')
crop('fence_broken','заборы горизонт.png',(40,124,478,290),.25,pivot=[220,113],mode='rgba')
crop('gate_leaf','заборы горизонт.png',(525,935,1006,1206),.25,pivot=[247,178],mode='rgba')
crop('fence_v','заборы вертикаль 1.png',(16,123,150,512),.25,pivot=[56,353])
crop('gate_post','Тайл декор.png',(23,293,62,384),.9,pivot=[20,85])
crop('gate_beam','Тайл избы.png',(641,350,722,381),1.6,pivot=[40,15],mode='opaque')
# A plot is an opaque original ground object, never a concept-board background.
crop('garden','огород 1.png',(48,99,197,233),.8,pivot=[75,130],mode='opaque')
# Earth tiles are pixel-exact 32px crops from clean textured samples (16 variants each).
terrain_sources=[('grass','Тайл земля, база.png',(33,152),4,4),('path','Тайл дороги.png',(37,127),4,4),('worn','Тайл земля, база.png',(33,555),4,4),('soil','Тайл земля, база.png',(33,354),4,4),('moss','Тайл дороги.png',(962,898),2,2),('puddle','Тайл дороги.png',(146,718),2,3)]
atlas=Image.new('RGBA',(512,32*len(terrain_sources)))
terrain=[]
for row,(name,source,(x0,y0),cols,rows_count) in enumerate(terrain_sources):
 im=Image.open(RAW/source).convert('RGBA')
 for i in range(16):
  index=i%(cols*rows_count)
  box=(x0+index%cols*32,y0+index//cols*32,x0+index%cols*32+32,y0+index//cols*32+32)
  atlas.paste(im.crop(box),(i*32,row*32))
  terrain.append({'kind':name,'source':source,'box':box,'atlas_cell':[i,row]})
atlas.save(BASE/'terrain.png')
# Edge masks retain source RGB; alpha is binary, respecting crisp pixel edges.
edge=Image.new('RGBA',(512,256));src=Image.open(RAW/'Тайл дороги.png').convert('RGBA');rng=random.Random(208)
for mask in range(16):
 for variant in range(8):
  tile=src.crop((37+variant%4*32,127+variant//4*32,69+variant%4*32,159+variant//4*32));a=np.array(tile)
  for y in range(32):
   for x in range(32):
    near=[]
    if not mask&1:near.append(y)
    if not mask&2:near.append(31-x)
    if not mask&4:near.append(31-y)
    if not mask&8:near.append(x)
    if near and min(near)<rng.randrange(2,8):a[y,x,3]=0
  idx=mask*8+variant;edge.paste(Image.fromarray(a),(idx%16*32,idx//16*32))
edge.save(BASE/'path_edges.png')
(BASE/'extraction.json').write_text(json.dumps({'objects':objects,'terrain':terrain},ensure_ascii=False,indent=2)+'\n')
(ROOT/'assets/stage2_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('Prepared',len(objects),'object crops;',len(terrain),'terrain tiles; indexed',len(catalog),'original images.')
