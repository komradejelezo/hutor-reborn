"""Stage 3.1: source-pixel surface synthesis for the existing two TileMapLayers.

Never edits the layout or original PNG. All RGB texels are copied from the two
original art sheets; noise controls selection only. Requires Pillow/numpy/scipy.
"""
from pathlib import Path
import hashlib
import json
import re
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

P = Path(__file__).resolve().parents[1]
B = P / 'assets/environment/krivaya_sosna'
OUT = B / 'surface_polish'
OUT.mkdir(exist_ok=True)
LAYOUT_PATH = B / 'expanded_layout.json'
LAYOUT = json.loads(LAYOUT_PATH.read_text())
W, H = LAYOUT['map_size']
RNG = np.random.default_rng(3106046)
SHEETS = ['Тайл земля, база.png', 'Тайл дороги.png']
RAW = [np.asarray(Image.open(B / 'source' / n).convert('RGB')) for n in SHEETS]
# Interior regions only: no reference-board labels, dark gutters or card frames.
REGIONS = {
    'grass': [(0, (33,152,161,280)), (0, (205,152,333,280)),
              (0, (375,152,503,280)), (0, (545,152,673,280)),
              (0, (1228,152,1356,280)), (0, (1057,555,1185,683))],
    'forest': [(1, (632,900,704,964)), (1, (732,900,802,964)),
               (1, (1070,900,1140,964)), (1, (1170,900,1240,964))],
    'road': [(1, (39,132,155,246)), (1, (188,132,303,246)),
             (1, (337,132,452,246)), (1, (486,132,601,246))],
    'worn': [(0, (33,555,161,683)), (0, (205,555,333,683))],
    'soil': [(0, (33,354,161,482)), (1, (36,718,126,814))],
}

def random_field(x, y, seed=0):
    x = np.asarray(x, dtype=np.uint32)
    y = np.asarray(y, dtype=np.uint32)
    n = x*np.uint32(374761393) + y*np.uint32(668265263) + np.uint32(seed)
    n = (n ^ (n >> 13))*np.uint32(1274126177)
    return ((n ^ (n >> 16)) & 65535).astype(np.float32)/65535

def smooth(a, b, value):
    t = np.clip((value-a)/(b-a), 0, 1)
    return t*t*(3-2*t)

def noise(x, y, scale, seed=0):
    fx, fy = x/scale, y/scale
    ix, iy = np.floor(fx).astype(np.int32), np.floor(fy).astype(np.int32)
    tx, ty = smooth(0, 1, fx-ix), smooth(0, 1, fy-iy)
    a = random_field(ix,iy,seed)*(1-tx) + random_field(ix+1,iy,seed)*tx
    b = random_field(ix,iy+1,seed)*(1-tx) + random_field(ix+1,iy+1,seed)*tx
    return a*(1-ty) + b*ty

def ellipse(x, y, cx, cy, rx, ry):
    return (np.sqrt(((x-cx)/rx)**2 + ((y-cy)/ry)**2)-1)*min(rx,ry)

def encode(sheet, x, y):
    return (np.uint32(sheet+1)<<22) | (y.astype(np.uint32)<<11) | x.astype(np.uint32)

def cut(cost):
    h,w = cost.shape
    dp = cost.astype(float).copy()
    parent = np.zeros((h,w),np.int16)
    for y in range(1,h):
        prev = np.pad(dp[y-1],(1,1),constant_values=np.inf)
        options = np.stack((prev[:w],prev[1:w+1],prev[2:]))
        best = options.argmin(0)
        dp[y] += options[best,np.arange(w)]
        parent[y] = np.arange(w)+best-1
    seam = np.empty(h,np.int16)
    seam[-1] = dp[-1].argmin()
    for y in range(h-1,0,-1):
        seam[y-1] = parent[y,seam[y]]
    return np.arange(w)[None,:] <= seam[:,None]

def tree_positions():
    scene = (P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn').read_text()
    refs = dict((i,n) for n,i in re.findall(r'path="res://scenes/objects/krivaya_sosna/([^"/]+)\.tscn" id="([^"]+)"',scene))
    trees = []
    for ref,x,y in re.findall(r'\[node[^\n]+parent="Actors/Nature"[^\n]+instance=ExtResource\("([^"]+)"\)\]\nposition = Vector2\(([^,]+), ([^)]+)\)',scene):
        if refs[ref].startswith('pine_') or refs[ref] in ['mixed_tree','crooked_pine']:
            trees.append((float(x),float(y)))
    assert len(trees)>150, len(trees)
    return trees

trees = tree_positions()
tree_mask = np.ones((H,W),bool)
for x,y in trees:
    tree_mask[min(H-1,round(y)),min(W-1,round(x))] = False
forest = (1-smooth(35,175,distance_transform_edt(tree_mask))).astype(np.float32)
del tree_mask
road_distance = np.full((H,W),1e6,np.float32)
mud = np.zeros((H,W),np.float32)
for y0 in range(0,H,128):
    y,x = np.mgrid[y0:min(y0+128,H),:W].astype(np.float32)
    distance = np.full(x.shape,1e6,np.float32)
    for road in LAYOUT['roads']:
        for a,b in zip(road['points'],road['points'][1:]):
            ax,ay = a
            dx,dy = b[0]-ax,b[1]-ay
            t = np.clip(((x-ax)*dx+(y-ay)*dy)/max(dx*dx+dy*dy,1),0,1)
            d = np.sqrt((x-ax-t*dx)**2+(y-ay-t*dy)**2)-road['radius']
            # Smooth the visual union only, up to four pixels per pair of joins.
            k = 16
            h = np.maximum(k-np.abs(distance-d),0)/k
            distance = np.minimum(distance,d)-h*h*k*.25
    p = LAYOUT['plaza']
    distance = np.minimum(distance,ellipse(x,y,*p['center'],*p['radii']))
    road_distance[y0:y0+len(y)] = distance
    for patch in LAYOUT['mud_patches']:
        m = 1-smooth(-18,22,ellipse(x,y,*patch)+(noise(x,y,47,113)-.5)*14)
        mud[y0:y0+len(y)] = np.maximum(mud[y0:y0+len(y)],m)

def quilt_world(name):
    """Nonperiodic native-scale patches; irregular scan steps avoid a patch grid."""
    patch = 56
    canvas = np.zeros((H+patch,W+patch,3),np.uint8)
    origin = np.zeros((H+patch,W+patch),np.uint32)
    yy = previous_y = row = 0
    while yy < H:
        xx = previous_x = 0
        top = previous_y+patch-yy if yy else 0
        while xx < W:
            cx,cy = min(W-1,xx+patch//2),min(H-1,yy+patch//2)
            if name=='ground':
                group = 'forest' if RNG.random() < forest[cy,cx]*.93 else 'grass'
            else:
                plaza = LAYOUT['plaza']
                worn = ellipse(cx,cy,*plaza['center'],*plaza['radii'])<0
                if RNG.random()<mud[cy,cx]*.7:
                    group='soil'
                elif RNG.random() < (.65 if worn else forest[cy,cx]*.7+.12):
                    group='worn'
                else:
                    group='road'
            left = previous_x+patch-xx if xx else 0
            old = canvas[yy:yy+patch,xx:xx+patch]
            old_origin = origin[yy:yy+patch,xx:xx+patch]
            candidates = []
            for _ in range(10):
                sheet,box = REGIONS[group][int(RNG.integers(len(REGIONS[group])))]
                sx = int(RNG.integers(box[0],box[2]-patch+1))
                sy = int(RNG.integers(box[1],box[3]-patch+1))
                sample = RAW[sheet][sy:sy+patch,sx:sx+patch]
                cost = 0.
                if left:
                    cost += np.square(old[:,:left].astype(np.int32)-sample[:,:left]).mean()
                if top:
                    cost += np.square(old[:top].astype(np.int32)-sample[:top]).mean()
                candidates.append((cost,sheet,sx,sy))
            _,sheet,sx,sy = min(candidates)
            sample = RAW[sheet][sy:sy+patch,sx:sx+patch].copy()
            ys,xs = np.mgrid[sy:sy+patch,sx:sx+patch]
            uv = encode(sheet,xs,ys)
            keep = np.zeros((patch,patch),bool)
            if left:
                keep[:,:left] |= cut(np.square(old[:,:left].astype(np.int32)-sample[:,:left]).sum(2))
            if top:
                keep[:top] |= cut(np.square(old[:top].astype(np.int32)-sample[:top]).sum(2).T).T
            sample[keep] = old[keep]
            uv[keep] = old_origin[keep]
            old[:] = sample
            old_origin[:] = uv
            previous_x = xx
            xx += int(RNG.integers(32,41))
        previous_y = yy
        yy += int(RNG.integers(32,41))
        row += 1
        if row%8==0:
            print('QUILT',name,yy,'/',H,flush=True)
    return canvas[:H,:W].copy(),origin[:H,:W].copy()

ground,ground_uv = quilt_world('ground')
path,path_uv = quilt_world('path')
with np.load(B/'surfaces/provenance.npz') as old_uv:
    stamp_origins = {name:old_uv[name].copy() for name in ['soil','moss']}
stamp_rgb = {name:np.asarray(Image.open(B/'surfaces'/(name+'.png')).convert('RGB')) for name in ['soil','moss']}
overlay = np.zeros((H,W,4),np.uint8)
overlay_uv = np.zeros((H,W),np.uint32)
kind_map = np.full((H//32,W//32),-1,np.int8)
for y0 in range(0,H,128):
    y,x = np.mgrid[y0:min(y0+128,H),:W]
    xf,yf = x.astype(np.float32),y.astype(np.float32)
    irregular = (noise(xf,yf,74,310)-.5)*13 + (noise(xf,yf,21,900)-.5)*5
    weight = 1-smooth(-16,18,road_distance[y0:y0+len(y)]+irregular)
    alpha = weight>random_field(x//2,y//2,415)
    rgb = path[y0:y0+len(y)].copy()
    uv = path_uv[y0:y0+len(y)].copy()
    kinds = np.where(alpha,0,-1)
    # Existing yard mud patches: native source texels, continuous irregular edges.
    for material,sheet,patches,terrain in [('soil',0,LAYOUT['mud_patches'],1),
                                         ('moss',1,LAYOUT['moss_patches'],-1)]:
        for cx,cy,rx,ry in patches:
            d = ellipse(xf,yf,cx,cy,rx,ry)+(noise(xf,yf,43,712)-.5)*19
            m = 1-smooth(-24,26,d)
            chosen = m>random_field(x//2+41,y//2,915)
            if terrain==-1:
                chosen &= ~alpha
            # These existing 256px materials have joined periodic borders; a raw
            # reference-card crop would reintroduce an internal straight seam.
            tx = (x-cx+int(rx)*7)%256
            ty = (y-cy+int(ry)*11)%256
            rgb[chosen] = stamp_rgb[material][ty[chosen],tx[chosen]]
            origin = stamp_origins[material][ty[chosen],tx[chosen]]
            uv[chosen] = encode(sheet,origin[:,0],origin[:,1])
            alpha |= chosen
            kinds[chosen] = terrain
    for cx,cy in LAYOUT['puddles']:
        tx,ty = x-(cx-40),y-(cy-48)
        valid = (tx>=0)&(tx<80)&(ty>=0)&(ty<96)
        m = 1-smooth(-9,7,ellipse(xf,yf,cx,cy,32,36)+(noise(xf,yf,17,627)-.5)*9)
        chosen = valid&(m>random_field(x//2+13,y//2,29))
        sx,sy = tx+146,ty+718
        rgb[chosen] = RAW[1][sy[chosen],sx[chosen]]
        uv[chosen] = encode(1,sx[chosen],sy[chosen])
        alpha |= chosen
        kinds[chosen] = 1
    dst = overlay[y0:y0+len(y)]
    dst[:,:,:3] = np.where(alpha[:,:,None],rgb,0)
    dst[:,:,3] = alpha*255
    overlay_uv[y0:y0+len(y)] = np.where(alpha,uv,0)
    kind_map[y0//32:(y0+len(y))//32] = kinds[16::32,16::32]

def feather_object(name):
    image = np.array(Image.open(B/'objects'/(name+'.png')).convert('RGBA'))
    y,x = np.mgrid[:image.shape[0],:image.shape[1]]
    if name=='common_house':
        # Ground apron only: the complete building and its steps are protected.
        weight = smooth(0,29,image.shape[0]-1-y)
        sides = smooth(0,15,np.minimum(x,image.shape[1]-1-x))
        weight = np.where(y>=264,weight*sides,1)
    else:
        edge = np.minimum.reduce((x,y,image.shape[1]-1-x,image.shape[0]-1-y))
        weight = smooth(0,14,edge)
        # Preserve all cabbage leaves; only the rectangular bed soil fades.
        rgb = image[:,:,:3].astype(np.int16)
        vegetation = (rgb[:,:,1]>=rgb[:,:,0])&(rgb[:,:,1]>rgb[:,:,2]+8)
        weight[vegetation] = 1
    keep = weight>random_field(x//2,y//2,772)
    image[:,:,3] = np.minimum(image[:,:,3],keep*255)
    Image.fromarray(image).save(OUT/(name+'_ground.png'))

feather_object('common_house')
feather_object('garden')
Image.fromarray(ground).save(OUT/'world_ground.png')
Image.fromarray(overlay).save(OUT/'world_overlay.png')
np.savez_compressed(OUT/'provenance.npz',ground=ground_uv,overlay=overlay_uv)
manifest = {
    'map_size':[W,H], 'layout_sha256':hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest(),
    'source_sheets':SHEETS, 'regions':REGIONS, 'trees':len(trees),
    'active_cells':np.argwhere(overlay[:,:,3].reshape(H//32,32,W//32,32).max((1,3))>0).tolist(),
    'cell_kinds':kind_map.tolist(), 'method':'nonperiodic min-cut native texels; world-space masks; binary alpha',
    'provenance_encoding':'((sheet_index+1)<<22)|(source_y<<11)|source_x; zero is transparent',
}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
print('PREPARED',W,H,len(manifest['active_cells']),'overlay cells; layout unchanged',flush=True)
