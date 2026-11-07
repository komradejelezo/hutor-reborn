"""Append native-pixel terrain and three local road links; never rewrite 3.1.
Packed 32px atlases contain only new cells and local transparent path additions.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'stage42'
OUT.mkdir(exist_ok=True)
W,H=2976,2560
OW,OH=2624,2176
RNG=np.random.default_rng(4206046)
SHEETS=['Тайл земля, база.png','Тайл дороги.png']
RAW=[np.asarray(Image.open(B/'source'/s).convert('RGB')) for s in SHEETS]
REGIONS={
 'forest':[(1,(632,900,704,964)),(1,(732,900,802,964)),(1,(1070,900,1140,964)),(1,(1170,900,1240,964)),(0,(1057,555,1185,683))],
 'road':[(1,(39,132,155,246)),(1,(188,132,303,246)),(1,(337,132,452,246)),(1,(486,132,601,246))],
}
roads=[
 {'name':'Road beyond entrance','points':[[1287,2140],[1282,2320],[1260,2560]],'radius':46},
 {'name':'Inn approach','points':[[1287,2110],[1390,2220],[1510,2310],[1688,2295],[1688,2236]],'radius':29},
 {'name':'Forgotten path','points':[[2370,1160],[2480,1110],[2590,1090],[2710,1050]],'radius':13},
]

def hashed(x,y,seed=0):
 x=np.asarray(x,dtype=np.uint32);y=np.asarray(y,dtype=np.uint32)
 n=x*np.uint32(374761393)+y*np.uint32(668265263)+np.uint32(seed)
 n=(n^(n>>13))*np.uint32(1274126177)
 return ((n^(n>>16))&65535).astype(np.float32)/65535
def smooth(a,b,v):
 t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
def noise(x,y,scale,seed):
 fx,fy=x/scale,y/scale;ix,iy=np.floor(fx).astype(int),np.floor(fy).astype(int)
 tx,ty=smooth(0,1,fx-ix),smooth(0,1,fy-iy)
 return (hashed(ix,iy,seed)*(1-tx)+hashed(ix+1,iy,seed)*tx)*(1-ty)+(hashed(ix,iy+1,seed)*(1-tx)+hashed(ix+1,iy+1,seed)*tx)*ty
def cut(cost):
 h,w=cost.shape;dp=cost.copy();parent=np.zeros((h,w),np.int16)
 for y in range(1,h):
  prev=np.pad(dp[y-1],(1,1),constant_values=np.inf);options=np.stack((prev[:w],prev[1:w+1],prev[2:]))
  best=options.argmin(0);dp[y]+=options[best,np.arange(w)];parent[y]=np.arange(w)+best-1
 seam=np.empty(h,np.int16);seam[-1]=dp[-1].argmin()
 for y in range(h-1,0,-1):seam[y-1]=parent[y,seam[y]]
 return np.arange(w)[None,:]<=seam[:,None]

y,x=np.mgrid[:H,:W]
distance=np.full((H,W),1e6,np.float32)
for road in roads:
 for a,b in zip(road['points'],road['points'][1:]):
  dx,dy=b[0]-a[0],b[1]-a[1];t=np.clip(((x-a[0])*dx+(y-a[1])*dy)/max(dx*dx+dy*dy,1),0,1)
  d=np.sqrt((x-a[0]-t*dx)**2+(y-a[1]-t*dy)**2)-road['radius']
  distance=np.minimum(distance,d)
for cx,cy,rx,ry in [(1688,2305,170,68),(2710,1050,45,23)]:
 distance=np.minimum(distance,(np.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)-1)*min(rx,ry))
weight=1-smooth(-13,19,distance+(noise(x,y,61,842)-.5)*15+(noise(x,y,19,421)-.5)*5)
alpha=weight>hashed(x//2,y//2,94)
old_overlay=np.asarray(Image.open(B/'surface_polish/world_overlay.png').convert('RGBA'))
# Every old visible road/detail pixel remains rendered by the original layer.
alpha[:OH,:OW] &= old_overlay[:,:,3]==0

def quilt(kind):
 patch=56;canvas=np.zeros((H+patch,W+patch,3),np.uint8);uv=np.zeros((H+patch,W+patch),np.uint32)
 known=np.zeros((H+patch,W+patch),bool)
 if kind=='forest':
  canvas[:OH,:OW]=np.asarray(Image.open(B/'surface_polish/world_ground.png').convert('RGB'))
  known[:OH,:OW]=True
 else:
  canvas[:OH,:OW]=old_overlay[:,:,:3];known[:OH,:OW]=old_overlay[:,:,3]>0
 yy=previous_y=0
 while yy<H:
  xx=previous_x=0;top=previous_y+patch-yy if yy else 0
  while xx<W:
   left=previous_x+patch-xx if xx else 0
   if kind=='forest' and xx+patch<=OW and yy+patch<=OH:
    previous_x=xx;xx+=36;continue
   if kind=='road' and not alpha[yy:min(yy+patch,H),xx:min(xx+patch,W)].any():
    previous_x=xx;xx+=36;continue
   old=canvas[yy:yy+patch,xx:xx+patch];old_uv=uv[yy:yy+patch,xx:xx+patch];valid=known[yy:yy+patch,xx:xx+patch]
   candidates=[]
   for _ in range(9):
    sheet,box=REGIONS[kind][int(RNG.integers(len(REGIONS[kind])))];sx=int(RNG.integers(box[0],box[2]-patch+1));sy=int(RNG.integers(box[1],box[3]-patch+1))
    sample=RAW[sheet][sy:sy+patch,sx:sx+patch]
    error=np.square(old.astype(np.int32)-sample).sum(2)*valid
    score=(error[:,:left].sum() if left else 0)+(error[:top].sum() if top else 0)
    candidates.append((score,sheet,sx,sy))
   _,sheet,sx,sy=min(candidates);sample=RAW[sheet][sy:sy+patch,sx:sx+patch].copy()
   syy,sxx=np.mgrid[sy:sy+patch,sx:sx+patch];origin=(np.uint32(sheet+1)<<22)|(syy.astype(np.uint32)<<11)|sxx.astype(np.uint32)
   error=np.square(old.astype(np.float64)-sample).sum(2)*valid;keep=np.zeros((patch,patch),bool)
   if left:keep[:,:left]|=cut(error[:,:left])
   if top:keep[:top]|=cut(error[:top].T).T
   keep &= valid
   # Original terrain is an immutable seed at the extension boundary.
   py,px=np.mgrid[yy:yy+patch,xx:xx+patch]
   fixed=(px<OW)&(py<OH) if kind=='forest' else (px<OW)&(py<OH)&valid
   keep|=fixed
   sample[keep]=old[keep];origin[keep]=old_uv[keep]
   old[:]=sample;old_uv[:]=origin;valid[:]=True
   previous_x=xx;xx+=int(RNG.integers(32,41))
  previous_y=yy;yy+=int(RNG.integers(32,41))
  if yy%300<40:print('QUILT',kind,yy,'/',H,flush=True)
 return canvas[:H,:W],uv[:H,:W]

ground,ground_uv=quilt('forest')
path,path_uv=quilt('road')
extension=np.ones((H//32,W//32),bool);extension[:OH//32,:OW//32]=False
active=alpha.reshape(H//32,32,W//32,32).max((1,3))
provenance={}
def pack(name,rgb,mask,occupied,origin):
 cells=np.argwhere(occupied);rows=(len(cells)+31)//32
 atlas=np.zeros((rows*32,1024,4),np.uint8);atlas_uv=np.zeros((rows*32,1024),np.uint32);mapping=[]
 for index,(cy,cx) in enumerate(cells):
  ax,ay=index%32,index//32;y0,x0=cy*32,cx*32
  atlas[ay*32:ay*32+32,ax*32:ax*32+32,:3]=rgb[y0:y0+32,x0:x0+32]
  atlas[ay*32:ay*32+32,ax*32:ax*32+32,3]=mask[y0:y0+32,x0:x0+32]*255
  atlas_uv[ay*32:ay*32+32,ax*32:ax*32+32]=origin[y0:y0+32,x0:x0+32]
  mapping.append([int(cx),int(cy),ax,ay])
 Image.fromarray(atlas).save(OUT/(name+'.png'));provenance[name]=atlas_uv
 return mapping
mapping={'ground':pack('extension_ground',ground,np.ones((H,W),bool),extension,ground_uv),'paths':pack('new_paths',path,alpha,active,path_uv)}
np.savez_compressed(OUT/'surface_provenance.npz',**provenance)
plan={'map_size':[W,H],'old_map_size':[OW,OH],'anchors':{'inn':[1688,2264],'abandoned':[2700,1030]},'roads':roads,'ground_cells':mapping['ground'],'path_cells':mapping['paths'],'source_sheets':SHEETS,'source_regions':REGIONS,'provenance_encoding':'((sheet+1)<<22)|(source_y<<11)|source_x','method':'native min-cut quilt; original layers and pixels retained; irregular binary-alpha road additions'}
(OUT/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
print('APPENDED',len(mapping['ground']),'ground cells;',len(mapping['paths']),'local path cells; approved 3.1 resources untouched')
