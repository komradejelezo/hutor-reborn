"""Pixel-preserving texture quilting and continuous world-space surface masks.
No resize, blur or new RGB colours: each output texel copies a provenanced texel
from existing archived art. Requires Pillow and numpy for authoring only.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json
P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'surfaces';OUT.mkdir(exist_ok=True)
LAYOUT=json.loads((B/'expanded_layout.json').read_text())
W,H=LAYOUT['map_size']
RNG=np.random.default_rng(4602)
SPECS={
 'grass':('Тайл земля, база.png',(33,152,161,280),512),
 'road':('Тайл дороги.png',(39,129,163,251),256),
 'soil':('Тайл земля, база.png',(33,354,161,482),256),
 'worn':('Тайл земля, база.png',(33,555,161,683),256),
 'moss':('Тайл дороги.png',(962,898,1026,962),256),
}

def cut_vertical(cost):
    """Minimum-error boundary through an overlap; never average either side."""
    h,w=cost.shape;dp=cost.astype(np.float64).copy();parent=np.zeros((h,w),np.int16)
    for y in range(1,h):
        prev=np.pad(dp[y-1],(1,1),constant_values=np.inf)
        choices=np.stack([prev[:w],prev[1:w+1],prev[2:]])
        best=choices.argmin(0)
        dp[y]+=choices[best,np.arange(w)]
        parent[y]=np.arange(w)+best-1
    seam=np.zeros(h,np.int16);seam[-1]=int(dp[-1].argmin())
    for y in range(h-1,0,-1):seam[y-1]=parent[y,seam[y]]
    return np.arange(w)[None,:]<=seam[:,None]

def periodic_edges(canvas,coords,width):
    """Join opposite borders by copying source texels through a minimum-error seam."""
    canvas=canvas.copy();coords=coords.copy()
    for axis in [1,0]:
        rgb=np.swapaxes(canvas,0,1) if axis==0 else canvas
        uv=np.swapaxes(coords,0,1) if axis==0 else coords
        old=rgb[:,:width].copy();candidate=rgb[:,-width:][:,::-1].copy()
        cuv=uv[:,-width:][:,::-1].copy()
        retain=cut_vertical(np.square(old.astype(float)-candidate).sum(2))
        rgb[:,:width]=np.where(retain[:,:,None],candidate,old)
        uv[:,:width]=np.where(retain[:,:,None],cuv,uv[:,:width])
    canvas[:,-1]=canvas[:,0];coords[:,-1]=coords[:,0]
    canvas[-1]=canvas[0];coords[-1]=coords[0]
    return canvas,coords

def quilt(name,source,box,size):
    src=np.array(Image.open(B/'source'/source).convert('RGB').crop(box))
    sh,sw=src.shape[:2];patch=48 if min(sh,sw)>96 else 32;overlap=12;step=patch-overlap
    full=size+patch
    canvas=np.zeros((full,full,3),np.uint8);coords=np.zeros((full,full,2),np.uint16)
    for yy in range(0,size,step):
        for xx in range(0,size,step):
            candidates=[]
            for k in range(18):
                sx=int(RNG.integers(0,sw-patch+1));sy=int(RNG.integers(0,sh-patch+1))
                sample=src[sy:sy+patch,sx:sx+patch]
                cost=0.
                if xx:cost+=np.square(canvas[yy:yy+patch,xx:xx+overlap].astype(float)-sample[:,:overlap]).mean()
                if yy:cost+=np.square(canvas[yy:yy+overlap,xx:xx+patch].astype(float)-sample[:overlap]).mean()
                candidates.append((cost,sx,sy))
            _,sx,sy=min(candidates)
            sample=src[sy:sy+patch,sx:sx+patch].copy()
            ys,xs=np.mgrid[sy:sy+patch,sx:sx+patch]
            provenance=np.stack([xs+box[0],ys+box[1]],axis=2).astype(np.uint16)
            old=canvas[yy:yy+patch,xx:xx+patch];old_coords=coords[yy:yy+patch,xx:xx+patch]
            retain=np.zeros((patch,patch),bool)
            if xx:
                cost=np.square(old[:,:overlap].astype(float)-sample[:,:overlap]).sum(2)
                retain[:,:overlap]|=cut_vertical(cost)
            if yy:
                cost=np.square(old[:overlap].astype(float)-sample[:overlap]).sum(2)
                retain[:overlap]|=cut_vertical(cost.T).T
            sample[retain]=old[retain];provenance[retain]=old_coords[retain]
            old[:]=sample;old_coords[:]=provenance
    canvas=canvas[:size,:size].copy();coords=coords[:size,:size].copy()
    # Reflection copies existing pixels; the provenance follows every seam.
    canvas,coords=periodic_edges(canvas,coords,24)
    Image.fromarray(canvas).save(OUT/(name+'.png'))
    print('QUILTED',name,size,flush=True)
    return canvas,coords

textures={};provenance={}
for name,(source,box,size) in SPECS.items():textures[name],provenance[name]=quilt(name,source,box,size)

def hash_noise(x,y):
    n=(x.astype(np.uint32)*np.uint32(374761393)+y.astype(np.uint32)*np.uint32(668265263))
    n=(n^(n>>13))*np.uint32(1274126177)
    return ((n^(n>>16))&65535).astype(np.float32)/65535

def ellipse_distance(x,y,cx,cy,rx,ry):
    return (np.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)-1)*min(rx,ry)

def sample(name,x,y):
    t=textures[name];return t[y%t.shape[0],x%t.shape[1]]

# The overlay is an atlas of native 32px cells, not a background sprite. Its masks
# use global coordinates, so both sides of every cell boundary are evaluated together.
overlay=np.zeros((H,W,4),np.uint8);kind_map=np.full((H//32,W//32),-1,np.int8)
for y0 in range(0,H,128):
    y,x=np.mgrid[y0:min(y0+128,H),0:W];xf=x.astype(np.float32);yf=y.astype(np.float32)
    noise=hash_noise(x//2,y//2)
    coarse=3*np.sin(xf*.037+yf*.021)+2*np.sin(xf*.013-yf*.053)
    dist=np.full(x.shape,1e6,np.float32)
    for road in LAYOUT['roads']:
        for aa,bb in zip(road['points'],road['points'][1:]):
            ax,ay=aa;bx,by=bb;dx=bx-ax;dy=by-ay
            t=np.clip(((xf-ax)*dx+(yf-ay)*dy)/max(dx*dx+dy*dy,1),0,1)
            d=np.sqrt((xf-ax-t*dx)**2+(yf-ay-t*dy)**2)-road['radius']
            dist=np.minimum(dist,d)
    plaza=LAYOUT['plaza'];dist=np.minimum(dist,ellipse_distance(xf,yf,*plaza['center'],*plaza['radii']))
    road_weight=np.clip((13-dist-coarse)/26,0,1)
    selected=road_weight>noise
    rgb=sample('road',x,y).copy();alpha=selected.copy();surface_kind=np.where(selected,0,-1)
    # Worn earth inside the wide square, and irregular mud at working yards.
    pd=ellipse_distance(xf,yf,*plaza['center'],plaza['radii'][0]*.8,plaza['radii'][1]*.7)
    worn=(pd<-4)&(hash_noise(x//3+21,y//3+10)>.18)
    rgb[worn]=sample('worn',x,y)[worn]
    for name,patches,terrain_id in [('moss',LAYOUT['moss_patches'],-1),('soil',LAYOUT['mud_patches'],1)]:
        for patch in patches:
            d=ellipse_distance(xf,yf,*patch)
            weight=np.clip((12-d-coarse)/24,0,1)
            mask=weight>hash_noise(x//2+61,y//2+13)
            if name=='moss':mask &= ~selected
            rgb[mask]=sample(name,x,y)[mask];alpha|=mask;surface_kind[mask]=terrain_id
    # Rounded irregular puddles use only the existing native 80×96 source crop.
    puddle=np.array(Image.open(B/'source'/'Тайл дороги.png').convert('RGB').crop((146,718,226,814)))
    for cx,cy in LAYOUT['puddles']:
        px=x-(cx-40);py=y-(cy-48)
        valid=(px>=0)&(px<80)&(py>=0)&(py<96)
        weight=np.clip((7-ellipse_distance(xf,yf,cx,cy,37,43)-coarse)/14,0,1)
        mask=valid&(weight>hash_noise(x//2+110,y//2+37))
        rgb[mask]=puddle[np.clip(py[mask],0,95),np.clip(px[mask],0,79)]
        alpha|=mask;surface_kind[mask]=1
    dst=overlay[y0:y0+x.shape[0]];dst[:,:,:3]=np.where(alpha[:,:,None],rgb,0);dst[:,:,3]=alpha*255
    for yy in range(0,x.shape[0],32):
        for xx in range(0,W,32):
            kind_map[(y0+yy)//32,xx//32]=surface_kind[yy+16,xx+16]
Image.fromarray(overlay).save(OUT/'world_overlay.png')
# Terrain brushes for native terrain painting: 16 side-peering variants per material.
brushes=Image.new('RGBA',(512,64));by,bx=np.mgrid[0:32,0:32]
for row,material in enumerate(['road','soil']):
    brush_rgb,brush_uv=periodic_edges(textures[material][:32,:32],provenance[material][:32,:32],8)
    provenance['brush_'+material]=brush_uv
    for mask in range(16):
        distance=np.full((32,32),100,np.float32)
        for bit,edge in [(1,by),(2,31-bx),(4,31-by),(8,bx)]:
            if not mask&bit:distance=np.minimum(distance,edge)
        alpha=np.clip((distance-1)/7,0,1)>hash_noise(bx//2+mask*17,by//2)
        tile=np.dstack([brush_rgb,alpha.astype(np.uint8)*255])
        brushes.paste(Image.fromarray(tile),(mask*32,row*32))
brushes.save(OUT/'terrain_brushes.png')
np.savez_compressed(OUT/'provenance.npz',**provenance)
# Remove the rectangular alpha boundary of the existing cabbage-bed crop.
bed=np.array(Image.open(B/'objects/garden.png').convert('RGBA'));gy,gx=np.mgrid[:bed.shape[0],:bed.shape[1]]
edge=np.minimum.reduce([gx,gy,bed.shape[1]-1-gx,bed.shape[0]-1-gy])
keep=np.clip(edge/8,0,1)>hash_noise(gx//2+400,gy//2)
bed[:,:,3]=np.minimum(bed[:,:,3],keep*255);Image.fromarray(bed).save(OUT/'garden_blended.png')
manifest={'map_size':[W,H],'materials':{k:{'source':v[0],'box':v[1],'size':v[2]} for k,v in SPECS.items()},'cell_kinds':kind_map.tolist(),'active_cells':np.argwhere(overlay[:,:,3].reshape(H//32,32,W//32,32).max((1,3))>0).tolist(),'method':'minimum-error overlap; source RGB copies; global-coordinate binary alpha; nearest'}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
print('Prepared expanded native surfaces',W,H,'active cells',len(manifest['active_cells']),flush=True)
