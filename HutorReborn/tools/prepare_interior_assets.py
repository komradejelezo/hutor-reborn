"""Reviewed modular crops of the user's original sheets; no complete room backgrounds.
Authoring only: Pillow, numpy, scipy. Runtime requires only Godot.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

P = Path(__file__).resolve().parents[1]
SOURCE = P / 'assets/environment/krivaya_sosna/source'
OUT = P / 'assets/interiors/stage44'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def crop(name, sheet, box, transparent=True, polygon=None):
    path = SOURCE / (sheet + '.png')
    image = Image.open(path).convert('RGBA').crop(box)
    data = np.array(image)
    if transparent:
        rgb = data[:, :, :3].astype(int)
        background = (rgb.max(2) < 60) & (rgb[:, :, 0] <= rgb[:, :, 1] + 2) & (rgb[:, :, 1] <= rgb[:, :, 2] + 9)
        seeds = np.zeros(background.shape, bool)
        seeds[0] = background[0]; seeds[-1] = background[-1]
        seeds[:, 0] |= background[:, 0]; seeds[:, -1] |= background[:, -1]
        keep = ~ndi.binary_propagation(seeds, mask=background)
        labels, _ = ndi.label(keep, np.ones((3, 3)))
        keep &= np.bincount(labels.ravel())[labels] >= 5
        data[:, :, 3] = ndi.binary_fill_holes(ndi.binary_closing(keep,iterations=1)) * 255
    if polygon:
        from PIL import ImageDraw
        mask = Image.new('L', image.size)
        ImageDraw.Draw(mask).polygon(polygon, fill=255)
        data[:, :, 3] = np.array(mask)
    Image.fromarray(data).save(OUT / (name + '.png'))
    records.append({'name': name, 'source': str(path.relative_to(P)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'box': box, 'size': image.size, 'method': 'native RGB; connected edge-background alpha removal' if transparent else 'native opaque tile crop', 'polygon': polygon})


# Actual interior modules below the catalogue headings, not illustrated rooms.
crop('counter', 'трактир', (784, 450, 1014, 510), polygon=[(0,0),(23,0),(23,14),(206,14),(206,6),(228,6),(228,58),(22,58),(0,40)])
crop('shelf_cups', 'трактир', (1034, 453, 1140, 524))
crop('fireplace', 'трактир', (1281, 449, 1348, 528), polygon=[(20,4),(41,4),(48,14),(52,14),(52,25),(61,32),(63,74),(4,74),(4,32),(14,24),(14,13)])
crop('table_round', 'трактир', (1451, 447, 1517, 487))
crop('table_set', 'трактир', (791, 629, 858, 700))
crop('bench', 'трактир', (1464, 559, 1512, 586))
crop('barrel', 'трактир', (1353, 476, 1395, 523))
crop('lantern', 'трактир', (1360, 548, 1395, 597))
crop('bed_old', 'трактир', (1111, 628, 1158, 710), polygon=[(3,4),(43,4),(43,78),(3,78)])
crop('table_small', 'трактир', (880, 632, 920, 700))
crop('pot', 'трактир', (1078, 719, 1120, 759))
crop('chair', 'трактир', (1435, 726, 1467, 758))
crop('stool', 'трактир', (1203, 727, 1231, 758))
crop('herbs', 'трактир', (1463, 717, 1501, 764))
crop('dry_food', 'трактир', (949, 719, 1021, 766))
crop('door', 'трактир', (791, 716, 848, 765))
crop('sacks', 'Тайл дома', (198, 773, 277, 824), polygon=[(8, 4), (69, 4), (76, 47), (0, 47)])
crop('bed', 'Тайл дома', (34, 886, 82, 977))
crop('chest', 'Тайл декор', (995, 155, 1045, 213))
crop('shelf_books', 'Тайл дома', (459, 768, 511, 827))
crop('desk', 'Тайл дома', (282, 769, 349, 835))
crop('wall_hanging', 'Тайл декор', (477, 292, 537, 393))
crop('hanging_pots', 'Тайл дома', (455, 886, 518, 943))
crop('cauldron', 'Тайл декор', (844, 486, 901, 545))
crop('basket', 'Тайл декор', (627, 609, 682, 672))
crop('bottles', 'Тайл декор', (1040, 287, 1098, 365))
crop('herb_line', 'Тайл декор', (809, 294, 910, 393))
crop('documents', 'Тайл декор', (1378, 662, 1407, 693))
crop('candle', 'трактир', (1360, 548, 1395, 597)) # Small oil lamp on tables.
# Individual native 32px floor cells. Their edges align on the original plank rows.
crop('floor_dark', 'Тайл дома', (1048, 467, 1080, 499), False)
crop('floor_warm', 'Тайл дома', (1164, 467, 1196, 499), False)
crop('floor_worn', 'Тайл избы', (960, 490, 992, 522), False)
crop('wall', 'Тайл избы', (44, 163, 76, 195), False)
crop('wall_old', 'Тайл избы', (44, 172, 76, 204), False)
# Keep the damaged wood a small original fragment, not a synthetic texture.
crop('broken_boards', 'Тайл избы', (944, 487, 976, 519), False, polygon=[(3,1),(30,3),(28,14),(31,23),(10,30),(2,27)])

# Native pixel quilting across tile boundaries avoids an obvious 32px rectangle.
# The atlas contains floor cells only; walls/furniture remain independent nodes.
def seam(error):
    costs = error.copy()
    parents = np.zeros(error.shape, np.int16)
    for y in range(1, error.shape[0]):
        for x in range(error.shape[1]):
            lo, hi = max(0, x-1), min(error.shape[1], x+2)
            prev = lo + costs[y-1, lo:hi].argmin()
            costs[y, x] += costs[y-1, prev]; parents[y, x] = prev
    x = costs[-1].argmin(); path = np.zeros(error.shape[0], np.int16)
    for y in range(error.shape[0]-1, -1, -1):
        path[y] = x; x = parents[y, x]
    return np.arange(error.shape[1])[None, :] < path[:, None]


provenance = {}
for room, sheet, box, size in [
    ('inn', 'Тайл дома', (1164,461,1228,525), (768,448)),
    ('elder', 'Тайл дома', (1048,461,1112,525), (576,384)),
    ('herbalist', 'Тайл избы', (949,486,1013,550), (576,384)),
]:
    image = Image.open(SOURCE / (sheet+'.png')).convert('RGB')
    sample = np.array(image.crop(box))
    width, height = size
    result = np.zeros((height+48, width+48, 3), np.uint8)
    coords = np.zeros((height+48, width+48), np.int32)
    rng = np.random.default_rng(440+len(room))
    for y in range(0, height, 32):
        for x in range(0, width, 32):
            candidates = []
            for sy in (0,8,16):
                for sx in (0,8,16):
                    patch = sample[sy:sy+48,sx:sx+48]
                    error = 0.0
                    if x: error += ((result[y:y+48,x:x+16].astype(float)-patch[:,:16])**2).mean()
                    if y: error += ((result[y:y+16,x:x+48].astype(float)-patch[:16])**2).mean()
                    candidates.append((error+rng.uniform(0,8), sx, sy))
            _, sx, sy = min(candidates)
            patch = sample[sy:sy+48,sx:sx+48]
            old = result[y:y+48,x:x+48]
            keep = np.zeros((48,48), bool)
            if x: keep[:,:16] |= seam(((old[:,:16].astype(float)-patch[:,:16])**2).sum(2))
            if y: keep[:16] |= seam(((old[:16].astype(float)-patch[:16])**2).sum(2).T).T
            old[~keep] = patch[~keep]
            yy, xx = np.indices((48,48))
            source_coords = (yy+sy+box[1])*image.width+xx+sx+box[0]
            coords[y:y+48,x:x+48][~keep] = source_coords[~keep]
    Image.fromarray(result[:height,:width]).save(OUT/('floor_atlas_'+room+'.png'))
    provenance[room] = coords[:height,:width]
    records.append({'name':'floor_atlas_'+room,'source':str((SOURCE/(sheet+'.png')).relative_to(P)), 'sha256':hashlib.sha256((SOURCE/(sheet+'.png')).read_bytes()).hexdigest(), 'box':box, 'size':size, 'method':'native min-cut source-pixel quilt; provenance in floor_provenance.npz', 'polygon':None})
np.savez_compressed(OUT/'floor_provenance.npz', **provenance)
(OUT / 'manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Prepared', len(records), 'native modular crops; all originals untouched')
