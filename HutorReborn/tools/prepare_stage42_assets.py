"""Extract original exterior modules only; preserve every retained RGB texel.
Authoring dependency: Pillow/numpy/scipy. Never edits an original resource.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

P = Path(__file__).resolve().parents[1]
B = P / 'assets/environment/krivaya_sosna'
OUT = B / 'stage42'
SCENES = P / 'scenes/objects/krivaya_sosna/stage42'
OUT.mkdir(exist_ok=True)
SCENES.mkdir(parents=True, exist_ok=True)
definitions = [
    ('inn_body', 'трактир.png', [18,85,260,391], [127,246], 1.15,
     [[35,22],[218,22],[222,148],[224,219],[30,219]], 242, [206,104,0,-54]),
    ('inn_left_wing', 'трактир.png', [16,830,143,980], [66,130], 1.15,
     [[12,14],[108,14],[111,115],[12,117]], 130, [116,87,0,-45]),
    ('inn_right_wing', 'трактир.png', [371,830,503,981], [65,131], 1.15,
     [[12,23],[115,23],[119,119],[10,119]], 131, [123,84,0,-43]),
    ('abandoned_house', 'Пустой дом.png', [370,125,595,416], [112,267], 1.0,
     [[21,128],[192,130],[194,251],[19,259]], 267, [174,92,0,-48]),
    ('hitching_rail', 'трактир.png', [503,641,627,704], [62,55], 0.9,
     None, 57, [104,11,0,-6]),
    ('inn_sign', 'трактир.png', [686,535,751,638], [33,96], 0.8,
     None, 98, None),
    ('herb_bed', 'Тайл земля, база.png', [33,354,153,454], [60,94], 1.0,
     None, 100, None),
]

manifest = []
for name, source, box, pivot, scale, core, ground_y, shape in definitions:
    rgb = np.asarray(Image.open(B/'source'/source).convert('RGB').crop(box))
    a = rgb.astype(np.int16)
    background = (a.max(2) < 49) & (a[:,:,0] <= a[:,:,1]+4) & (a[:,:,0] <= a[:,:,2]+7)
    edge = np.zeros(background.shape, bool)
    edge[0] = background[0]; edge[-1] = background[-1]
    edge[:,0] |= background[:,0]; edge[:,-1] |= background[:,-1]
    keep = ~ndi.binary_propagation(edge, mask=background)
    if core:
        protected = Image.new('1', (rgb.shape[1],rgb.shape[0]))
        ImageDraw.Draw(protected).polygon(core, fill=1)
        keep |= np.asarray(protected)
    labels, _ = ndi.label(keep)
    keep &= np.bincount(labels.ravel())[labels] >= 4
    y,x = np.mgrid[:rgb.shape[0],:rgb.shape[1]]
    # Binary, irregular apron edges; never feather the actual building/steps.
    distance = np.minimum(x, rgb.shape[1]-1-x)
    weight = np.clip((rgb.shape[0]-1-y)/max(rgb.shape[0]-ground_y,1),0,1)
    weight *= np.clip(distance/12,0,1)
    threshold = ((x//2*37+y//2*71)%101)/101
    keep &= (y<ground_y) | (weight>threshold)
    if name == 'herb_bed':
        d = ((x-59.5)/59)**2 + ((y-49.5)/49)**2
        keep = d < (1.0 - threshold*0.18)
    rgba = np.dstack((rgb, keep.astype(np.uint8)*255))
    Image.fromarray(rgba).save(OUT/(name+'.png'))
    scene = '[gd_scene format=3]\n\n[ext_resource type="Texture2D" path="res://assets/environment/krivaya_sosna/stage42/%s.png" id="1"]\n\n' % name
    if shape:
        scene += '[sub_resource type="RectangleShape2D" id="Footprint"]\nsize = Vector2(%s, %s)\n\n' % tuple(shape[:2])
    scene += '[node name="%s" type="Node2D"]\nmetadata/stage42_asset = "%s"\n\n' % (''.join(s.title() for s in name.split('_')), name)
    scene += '[node name="Art" type="Sprite2D" parent="."]\ntexture_filter = 1\nscale = Vector2(%s, %s)\ntexture = ExtResource("1")\ncentered = false\noffset = Vector2(%s, %s)\n' % (scale,scale,-pivot[0],-pivot[1])
    if shape:
        scene += '\n[node name="Solid" type="StaticBody2D" parent="."]\ncollision_mask = 2\n\n[node name="Footprint" type="CollisionShape2D" parent="Solid"]\nposition = Vector2(%s, %s)\nshape = SubResource("Footprint")\n' % tuple(shape[2:])
    if name == 'abandoned_house':
        scene += '\n[node name="Entrance" type="Marker2D" parent="."]\nposition = Vector2(10, 20)\nmetadata/interior_id = "abandoned_house"\nmetadata/transition_enabled = false\n'
    (SCENES/(name+'.tscn')).write_text(scene)
    manifest.append({'name':name,'source':source,'box':box,'pivot':pivot,'scale':scale,'core':core,'ground_y':ground_y,'footprint':shape,'rgb_method':'exact source crop; binary alpha only'})
(OUT/'assets.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Prepared six exterior modules and one native soil bed; no source images overwritten')
