"""Stage 3.2: reviewed source crops, binary alpha and one shared prop atlas.
Copies original RGB without repainting/resizing. Authoring: Pillow/numpy/scipy.
"""
from pathlib import Path
import json
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'stage32'
SCENES=P/'scenes/objects/krivaya_sosna/stage32'
OUT.mkdir(exist_ok=True)
SCENES.mkdir(exist_ok=True)
SPECS=[]

def asset(name,source,box,scale=.65,solid=None,mode='dark',polygon=None,protect=None):
    raw=Image.open(B/'source'/source).convert('RGBA').crop(box)
    a=np.array(raw)
    rgb=a[:,:,:3].astype(np.int16)
    background=(rgb.max(2)<40)&((rgb[:,:,0]-rgb[:,:,2])<9)&(np.abs(rgb[:,:,0]-rgb[:,:,1])<8)
    seed=np.zeros(background.shape,bool)
    seed[0]=background[0];seed[-1]=background[-1]
    seed[:,0]|=background[:,0];seed[:,-1]|=background[:,-1]
    keep=~ndi.binary_propagation(seed,mask=background)
    if mode=='charred':
        background=(rgb[:,:,2]>=rgb[:,:,0]-1)&(rgb[:,:,1]>=rgb[:,:,0]-1)&(rgb.max(2)<45)
        seed=np.zeros(background.shape,bool)
        seed[0]=background[0];seed[-1]=background[-1]
        seed[:,0]|=background[:,0];seed[:,-1]|=background[:,-1]
        keep=~ndi.binary_propagation(seed,mask=background)
    if mode=='bush':
        keep=(rgb[:,:,0]>rgb[:,:,2]+12)&(rgb[:,:,1]>rgb[:,:,2]+12)&(rgb.max(2)>72)
        keep=ndi.binary_closing(keep,iterations=1)
        keep=ndi.binary_fill_holes(keep)
        core=Image.new('1',raw.size)
        ImageDraw.Draw(core).polygon([(33,30),(49,28),(58,45),(51,58),(40,63),(29,50)],fill=1)
        keep|=np.array(core)
    if protect:
        core=Image.new('1',raw.size)
        for points in protect:ImageDraw.Draw(core).polygon(points,fill=1)
        keep|=np.array(core)
    if polygon:
        mask=Image.new('1',raw.size)
        ImageDraw.Draw(mask).polygon(polygon,fill=1)
        keep&=np.array(mask)
    labels,_=ndi.label(keep)
    counts=np.bincount(labels.ravel())
    keep&=counts[labels]>=3
    a[:,:,3]=keep*255
    visible=np.argwhere(keep)
    assert len(visible)>40,name
    pivot=[raw.width/2,int(visible[:,0].max())-2]
    SPECS.append({'name':name,'source':source,'box':box,'scale':scale,'pivot':pivot,
                  'solid':solid,'mode':mode,'polygon':polygon,'protect':protect,'image':Image.fromarray(a)})

D='Тайл декор.png'
L='Тайлы лесозаготовка.png'
F='Тайлы поваленные деревья.png'
N='Тайл природа.png'
asset('sack_tied',D,(1162,146,1213,217),.60)
asset('grain_sack',D,(1218,286,1276,364),.60)
asset('grain_basin',D,(1158,286,1216,363),.60)
asset('bottle_crate',D,(1040,287,1098,365),.60)
asset('basket',D,(627,609,682,672),.60)
asset('bucket',D,(626,484,672,546),.60)
asset('wash_basin',D,(674,488,727,548),.55,polygon=[(5,7),(34,4),(50,12),(50,39),(27,56),(0,43),(0,18)])
asset('tankard',D,(729,488,765,536),.40,polygon=[(0,0),(28,0),(31,26),(24,46),(0,46)])
asset('kitchen_pot',D,(850,486,905,548),.60)
asset('cooking_tripod',D,(769,442,847,551),.65,[44,12,0,-6],polygon=[(24,0),(37,4),(77,96),(65,108),(3,108),(0,90)])
asset('wood_trough',D,(547,484,622,548),.70)
asset('short_bench',D,(902,486,977,550),.75,[48,12,0,-6])
asset('stool',D,(979,497,1020,553),.60)
asset('shovel',D,(765,582,808,673),.60)
asset('pitchfork',D,(820,582,866,673),.60)
asset('broom',D,(874,583,922,673),.60)
asset('herb_line',D,(809,294,910,393),.65,[60,12,0,-6])
asset('hide_rack',D,(472,284,540,391),.70,[36,12,0,-6])
asset('herb_pot',D,(831,756,880,834),.60)
asset('white_herbs',D,(886,756,943,834),.60)
asset('axe_stump',L,(925,395,1025,474),.60,[26,14,0,-7])
asset('saw',L,(1040,395,1240,471),.45)
asset('stump_roots',L,(794,114,912,204),.60,[32,18,0,-9])
asset('old_stump',L,(932,116,1062,205),.55,[30,16,0,-8])
asset('charred_snag',L,(916,785,1051,862),.90,[22,14,0,-7],mode='charred')
asset('dry_snag','кривая сосна.png',(1038,815,1140,940),1.00,[17,17,0,-8])
asset('fallen_a',F,(38,137,168,189),.90,[96,15,0,-8])
asset('fallen_b',F,(223,132,450,214),.70,[122,17,0,-8])
asset('roots',F,(819,131,941,216),.60)
asset('branches',F,(980,500,1094,565),.65)
asset('bark',F,(1110,500,1215,563),.55)
asset('chips',F,(1240,499,1348,564),.55)
asset('leaf_litter',F,(1375,501,1492,567),.60)
asset('bush_round',N,(1033,164,1120,232),.72,mode='bush',polygon=[(23,2),(57,0),(85,25),(84,52),(59,65),(21,63),(1,45),(2,19)])
asset('bush_sparse',N,(1174,164,1260,233),.75,mode='bush',polygon=[(22,1),(59,2),(85,23),(82,51),(58,67),(24,64),(1,41),(3,18)])
asset('bush_berries',N,(1033,329,1120,407),.65,mode='bush',polygon=[(24,0),(58,1),(85,31),(84,60),(58,75),(21,71),(1,47),(4,20)])

# Shelf packing with two extruded border pixels and a transparent two-pixel gap.
width=1024
positions={}
x=y=row_height=0
for item in sorted(SPECS,key=lambda r:-r['image'].height):
    w,h=item['image'].size
    if x+w+8>width:
        y+=row_height;x=0;row_height=0
    positions[item['name']]=[x+4,y+4,w,h]
    x+=w+8;row_height=max(row_height,h+8)
height=2**math.ceil(math.log2(y+row_height))
atlas=Image.new('RGBA',(width,height))
for item in SPECS:
    x,y,w,h=positions[item['name']]
    im=item.pop('image')
    atlas.paste(im,(x,y))
    atlas.paste(im.crop((0,0,1,h)).resize((2,h),Image.Resampling.NEAREST),(x-2,y))
    atlas.paste(im.crop((w-1,0,w,h)).resize((2,h),Image.Resampling.NEAREST),(x+w,y))
    atlas.paste(im.crop((0,0,w,1)).resize((w,2),Image.Resampling.NEAREST),(x,y-2))
    atlas.paste(im.crop((0,h-1,w,h)).resize((w,2),Image.Resampling.NEAREST),(x,y+h))
    item['atlas_region']=[x,y,w,h]
atlas.save(OUT/'environment_atlas.png')
(OUT/'assets.json').write_text(json.dumps({'atlas_size':[width,height],'objects':SPECS},ensure_ascii=False,indent=2)+'\n')
for item in SPECS:
    key=item['name'];x,y,w,h=item['atlas_region'];s=item['scale'];px,py=item['pivot']
    body=''
    shape=''
    if item['solid']:
        sw,sh,sx,sy=item['solid']
        shape=f'\n[sub_resource type="RectangleShape2D" id="Footprint"]\nsize = Vector2({sw}, {sh})\n'
        body=f'\n[node name="Solid" type="StaticBody2D" parent="."]\ncollision_mask = 2\n\n[node name="Footprint" type="CollisionShape2D" parent="Solid"]\nposition = Vector2({sx}, {sy})\nshape = SubResource("Footprint")\n'
    text=f'''[gd_scene format=3]

[ext_resource type="Texture2D" path="res://assets/environment/krivaya_sosna/stage32/environment_atlas.png" id="1"]

[sub_resource type="AtlasTexture" id="ArtTexture"]
atlas = ExtResource("1")
region = Rect2({x}, {y}, {w}, {h})
filter_clip = true
{shape}
[node name="{key.title().replace('_','')}" type="Node2D"]
metadata/detail_asset = "{key}"

[node name="Art" type="Sprite2D" parent="."]
texture_filter = 1
scale = Vector2({s}, {s})
texture = SubResource("ArtTexture")
centered = false
offset = Vector2({-px}, {-py})
{body}'''
    (SCENES/(key+'.tscn')).write_text(text)
for name in ['pine_0','pine_1','pine_2','pine_3','mixed_tree']:
    text=f'''[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/objects/krivaya_sosna/{name}.tscn" id="1"]

[node name="MirroredTree" instance=ExtResource("1")]

[node name="Art" parent="." index="0"]
flip_h = true
'''
    (SCENES/('mirror_'+name+'.tscn')).write_text(text)
print('Prepared',len(SPECS),'source crops in one',width,'x',height,'atlas; 5 mirrored native tree scenes')
