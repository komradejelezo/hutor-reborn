"""Stage 4.5: native crops and source-pixel derivatives, preserving all older art.
Authoring only: Pillow/numpy/scipy. No original image or 4.4 output is rewritten.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

P = Path(__file__).resolve().parents[1]
SOURCE = P/'assets/environment/krivaya_sosna/source'
OUT = P/'assets/interiors/stage45'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def crop(name, sheet, box, polygon=None, holes=None):
    source = SOURCE/(sheet+'.png')
    image = Image.open(source).convert('RGBA').crop(box)
    data = np.array(image)
    rgb = data[:,:,:3].astype(int)
    background = (rgb.max(2)<60) & (rgb[:,:,0]<=rgb[:,:,1]+2) & (rgb[:,:,1]<=rgb[:,:,2]+9)
    seed = np.zeros(background.shape, bool)
    seed[0]=background[0];seed[-1]=background[-1]
    seed[:,0]|=background[:,0];seed[:,-1]|=background[:,-1]
    keep = ~ndi.binary_propagation(seed, mask=background)
    labels,_ = ndi.label(keep, np.ones((3,3)))
    keep &= np.bincount(labels.ravel())[labels]>=5
    data[:,:,3] = ndi.binary_fill_holes(ndi.binary_closing(keep, iterations=1))*255
    if polygon:
        from PIL import ImageDraw
        mask=Image.new('L',image.size)
        ImageDraw.Draw(mask).polygon(polygon,fill=255)
        for hole in holes or []:ImageDraw.Draw(mask).rectangle(hole,fill=0)
        data[:,:,3]=np.array(mask)
    Image.fromarray(data).save(OUT/(name+'.png'))
    records.append({'name':name,'source':str(source.relative_to(P)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'box':box,'size':image.size,'method':'native RGB crop; binary silhouette alpha','polygon':polygon,'holes':holes})


crop('window','Тайл дома',(46,465,108,506),[(0,0),(61,0),(61,40),(0,40)])
crop('armchair','трактир',(946,628,997,704))
crop('chair','Тайл дома',(377,772,415,827),[(4,2),(11,2),(11,8),(27,8),(27,2),(34,2),(34,29),(36,29),(36,40),(32,40),(32,53),(25,53),(25,41),(13,41),(13,52),(6,52),(6,40),(2,40),(2,29),(4,29)],[[12,18,26,25]])
crop('pipe','Тайлы лесозаготовка',(1138,951,1210,1005))
crop('papers','Тайлы лесозаготовка',(1000,943,1106,1005))
crop('axe','Тайлы лесозаготовка',(818,388,878,432))
crop('linen_line','Тайлы лесозаготовка',(23,792,155,874))
crop('rope_block','Тайлы лесозаготовка',(1398,501,1512,591))
crop('grain_sack','Тайл декор',(1218,286,1276,364))
crop('crate','Тайл декор',(934,286,984,357))
crop('shovel','Тайл декор',(765,582,808,673))
crop('tool_rack','Тайлы лесозаготовка',(1038,390,1162,466))

# Actual boots, not the footprints printed on the logging catalogue. Read only.
source=P/'assets/npc/stage43/woodcutter/atlas.png'
box=(36,70,56,81)
boots=Image.open(source).convert('RGBA').crop(box)
data=np.array(boots);rgb=data[:,:,:3].astype(int)
keep=(data[:,:,3]>0)&(rgb[:,:,0]>rgb[:,:,1]+3)&(rgb.max(2)-rgb.min(2)>8)
data[:,:,3]=ndi.binary_fill_holes(keep)*255
Image.fromarray(data).save(OUT/'work_boots.png')
records.append({'name':'work_boots','source':str(source.relative_to(P)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'box':box,'size':boots.size,'method':'native archived woodcutter boot pixels; grey ground guide removed from alpha'})

# Two copies of the same original bed form one modest parents' sleeping platform.
source=P/'assets/interiors/stage44/bed.png'
bed=Image.open(source).convert('RGBA')
double=Image.new('RGBA',(bed.width+40,bed.height))
double.paste(bed,(0,0));double.paste(bed,(40,0),bed)
double.save(OUT/'parents_bed.png')
records.append({'name':'parents_bed','source':str(source.relative_to(P)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':double.size,'method':'two native original-bed copies; no stretching','placements':[[0,0],[40,0]]})

provenance={}
old=P/'assets/interiors/stage44'
old_provenance=np.load(old/'floor_provenance.npz')
old_manifest=json.loads((old/'manifest.json').read_text(encoding='utf-8'))
for room,base,box in [
    ('woodcutter','inn',(64,64,512,384)),
    ('old_man','elder',(64,32,416,320)),
    ('storehouse','herbalist',(64,32,480,352)),
]:
    source=old/('floor_atlas_'+base+'.png')
    image=Image.open(source).crop(box)
    image.save(OUT/('floor_atlas_'+room+'.png'))
    x0,y0,x1,y1=box
    provenance[room]=old_provenance[base][y0:y1,x0:x1]
    original=next(r for r in old_manifest if r['name']=='floor_atlas_'+base)
    records.append({'name':'floor_atlas_'+room,'source':str(source.relative_to(P)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'box':box,'size':image.size,'method':'native contiguous crop of approved 4.4 source-pixel quilt','original_source':original['source']})
np.savez_compressed(OUT/'floor_provenance.npz',**provenance)
(OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared',len(records),'native crops/derivatives; older assets untouched')
