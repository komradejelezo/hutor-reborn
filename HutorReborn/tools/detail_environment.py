"""Stage 3.2 authoring: redistribute existing instances, preserving terrain bytes.
No runtime generation, no new map. Python 3 + numpy; art preparation is separate.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import numpy as np

P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'stage32'
SCENE=P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn'
text=SCENE.read_text()
layout=json.loads((B/'expanded_layout.json').read_text())
assets={a['name']:a for a in json.loads((OUT/'assets.json').read_text())['objects']}
originals={a['name']:a for a in json.loads((B/'extraction.json').read_text())['objects']}
rng=np.random.default_rng(3206046)
before=OUT/'base_objects.json'
if not before.exists():
    refs=dict((i,n) for n,i in re.findall(r'path="res://scenes/objects/krivaya_sosna/([^"/]+)\.tscn" id="([^"]+)"',text))
    nodes=[]
    for header,body in re.findall(r'^(\[node[^\n]+\])\n(.*?)(?=^\[|\Z)',text,re.M|re.S):
        ref=re.search(r'instance=ExtResource\("([^"]+)"\)',header)
        if not ref or ref[1] not in refs:continue
        name=re.search(r'name="([^"]+)"',header)[1]
        parent=re.search(r'parent="([^"]*)"',header)[1]
        uid=re.search(r'unique_id=(\d+)',header)[1]
        pos=re.search(r'position = Vector2\(([^,]+), ([^)]+)\)',body)
        point=[float(pos[1]),float(pos[2])] if pos else [0.0,0.0]
        nodes.append({'name':name,'parent':parent,'uid':uid,'ref':ref[1],'kind':refs[ref[1]],'position':point})
    assert len(nodes)==703,len(nodes)
    before.write_text(json.dumps(nodes,ensure_ascii=False,indent=2)+'\n')
nodes=json.loads(before.read_text())
trees=[n for n in nodes if n['kind'].startswith('pine_') or n['kind']=='mixed_tree']
slots=[n for n in nodes if n['parent']=='Actors/Nature' and n['kind'] in ['grass','flowers']]
assert len(trees)==292 and len(slots)==193
movable={n['uid'] for n in trees+slots}

def footprint(kind):
    path=P/'scenes/objects/krivaya_sosna'/((kind+'.tscn') if kind in originals else ('stage32/'+kind+'.tscn'))
    data=path.read_text()
    if 'type="CollisionShape2D"' not in data:return None
    size=re.search(r'\[sub_resource type="RectangleShape2D"[^\n]*\]\nsize = Vector2\(([^,]+), ([^)]+)\)',data)
    pos=re.search(r'\[node name="Footprint" type="CollisionShape2D"[^\n]*\]\nposition = Vector2\(([^,]+), ([^)]+)\)',data)
    assert size and pos,kind
    return [float(size[1]),float(size[2]),float(pos[1]),float(pos[2])]

fixed=[]
for n in nodes:
    if n['uid'] in movable:continue
    f=footprint(n['kind'])
    if f:
        w,h,dx,dy=f;x,y=n['position'];fixed.append((x+dx-w/2,y+dy-h/2,x+dx+w/2,y+dy+h/2))
roads=[]
for road in layout['roads']:
    a=np.array(road['points'],float)
    roads.extend((p,q,float(road['radius'])) for p,q in zip(a,a[1:]))

def road_clearance(point):
    p=np.asarray(point,float)
    return min(np.linalg.norm(p-(a+np.clip(np.dot(p-a,b-a)/np.dot(b-a,b-a),0,1)*(b-a)))-r for a,b,r in roads)

def outside_town(x,y):
    left=335+50*math.sin(y/163)+23*math.sin(y/67)
    right=2190+65*math.sin(y/207+.7)+20*math.sin(y/71)
    north=449+58*math.sin(x/223)+22*math.sin(x/87)
    south=1845+55*math.sin(x/191)+19*math.sin(x/73)
    return x<left or x>right or y<north or y>south

def overlaps(a,b,pad=0):
    return a[0]<b[2]+pad and a[2]>b[0]-pad and a[1]<b[3]+pad and a[3]>b[1]-pad

def box_at(point,shape):
    w,h,dx,dy=shape;x,y=point
    return [x+dx-w/2,y+dy-h/2,x+dx+w/2,y+dy+h/2]

house_boxes=[]
for n in nodes:
    if n['kind'].endswith('_house'):
        a=originals[n['kind']];x,y=n['position'];px,py=a['pivot'];w,h=a['size'];s=a['scale']
        house_boxes.append([x-px*s,y-py*s,x+(w-px)*s,y+(h-py)*s])
landmark=[312,455,744,954]
positions=[]
plan=[]
cluster_centers=[(120,300),(640,230),(1030,230),(1820,190),(2280,440),(2440,820),(2410,1660),(1900,2050),(850,2070),(250,1920),(100,1110)]
attempts=0
while len(positions)<len(trees):
    attempts+=1
    assert attempts<120000,'forest sampling exhausted'
    if rng.random()<.66:
        center=cluster_centers[int(rng.integers(len(cluster_centers)))]
        x,y=rng.normal(center,[150,155])
    else:x,y=rng.uniform([52,90],[2572,2128])
    x,y=round(float(x)),round(float(y))
    if not (52<=x<=2572 and 90<=y<=2128 and outside_town(x,y)):continue
    if road_clearance([x,y])<65:continue
    if any(math.dist([x,y],q['position'])<125 for q in layout['exploration_points']):continue
    image=[x-92,y-270,x+92,y+24]
    if overlaps(image,landmark) or any(overlaps(image,b,8) for b in house_boxes):continue
    if any(overlaps([x-14,y-23,x+14,y+4],b,12) for b in fixed):continue
    separation=53+14*(.5+.5*math.sin(x/170+y/125))
    if any(math.dist([x,y],p)<separation for p in positions):continue
    positions.append([x,y])
rng.shuffle(positions)
for n,pos in zip(trees,positions):
    kind=('mirror_'+n['kind']) if rng.random()<.48 else n['kind']
    plan.append({**n,'position':pos,'kind':kind,'theme':'forest'})

def detail(theme,kind,point,parent='Actors/Props'):
    plan.append({'name':f'S32_{theme}_{kind}_{len(plan)}','parent':parent,'kind':kind,'position':list(point),'theme':theme})

for theme,items in {
    'Elder':[('wood_store',(713,770)),('barrel',(705,844)),('short_bench',(1120,695)),('basket',(842,840)),('bucket',(835,770)),('broom',(804,739)),('wood_trough',(844,747)),('sack_tied',(805,823))],
    'Miller':[('grain_sack',(1625,785)),('sack_tied',(1592,767)),('grain_basin',(1644,823)),('bottle_crate',(1810,802)),('crate',(1801,841)),('pitchfork',(1580,738)),('saw',(1620,738)),('grain_sack',(1820,769))],
    'Common':[('cooking_tripod',(1108,1261)),('basket',(1148,1246)),('kitchen_pot',(1178,1283)),('wash_basin',(1207,1252)),('tankard',(1388,1269)),('sack_tied',(1457,1275)),('wood_trough',(1443,1196)),('basket',(1138,1188))],
    'Hunter':[('hide_rack',(754,1673)),('axe_stump',(729,1700)),('saw',(693,1578)),('basket',(792,1704)),('short_bench',(930,1685)),('stool',(977,1665)),('wood_trough',(754,1606)),('sack_tied',(958,1637))],
    'Herbalist':[('herb_line',(1534,1585)),('herb_pot',(1936,1659)),('herb_pot',(1980,1633)),('white_herbs',(1810,1685)),('basket',(1780,1643)),('bottle_crate',(1838,1698)),('broom',(1558,1634)),('bucket',(1886,1683))],
    'Well':[('bucket',(1242,1555)),('wash_basin',(1222,1596)),('basket',(1195,1558)),('wood_trough',(1174,1536)),('bush_sparse',(1175,1596)),('leaf_litter',(1225,1530))],
}.items():
    for kind,point in items:
        parent='Ground Objects' if kind in ['leaf_litter','bark','chips'] else ('Actors/Nature' if kind.startswith('bush') or kind in ['herb_pot','white_herbs'] else 'Actors/Props')
        detail(theme,kind,point,parent)

added=plan[len(trees):]
solid_points=[]
for n in added:
    f=footprint(n['kind'])
    if f:solid_points.append((n['position'],f))

def forest_point(kind,margin=45):
    f=footprint(kind)
    for attempt in range(30000):
        x,y=np.rint(rng.uniform([75,140],[2549,2100])).astype(int)
        if not outside_town(x,y) or road_clearance([x,y])<margin:continue
        if any(math.dist([x,y],q['position'])<112 for q in layout['exploration_points']):continue
        if any(math.dist([x,y],p)<40 for p in positions):continue
        if overlaps([x-25,y-50,x+25,y+5],landmark):continue
        if any(overlaps([x-25,y-40,x+25,y+6],b,4) for b in house_boxes):continue
        if f:
            box=box_at([x,y],f)
            if any(overlaps(box,b,10) for b in fixed):continue
            if any(overlaps(box,box_at(p,s),10) for p,s in solid_points):continue
            solid_points.append(([int(x),int(y)],f))
        return [int(x),int(y)]
    raise AssertionError(('no space',kind))

for i in range(24):
    kind=['bush_round','bush_sparse','bush_berries'][i%3]
    detail('Understory',kind,forest_point(kind,34),'Actors/Nature')
for i in range(8):
    kind='dry_snag' if i%3 else 'charred_snag'
    detail('Deadwood',kind,forest_point(kind,55),'Actors/Nature')
for i in range(6):
    kind='fallen_a' if i%2 else 'fallen_b'
    detail('Fallen',kind,forest_point(kind,85),'Actors/Props')
for i in range(7):
    kind='old_stump' if i%2 else 'stump_roots'
    detail('Stumps',kind,forest_point(kind,45),'Actors/Props')
for i in range(28):
    kind=['roots','branches','bark','chips','leaf_litter'][i%5]
    pos=forest_point(kind,28)
    if i<3:pos=[[400,949],[449,954],[592,892]][i]
    detail('Litter',kind,pos,'Ground Objects')
assert len(plan)-len(trees)==119

# Use the remaining 74 original plant instances in loose, irregular clumps.
centers=[(655,1030),(2055,1030),(2100,1620),(485,1740),(1100,1750),(1530,1390),(735,860),(1970,875),(220,1650),(2380,1630),(430,1200),(2200,1810),(720,1950),(1200,1900)]
plants=[]
for n in slots[119:]:
    for attempt in range(10000):
        center=centers[int(rng.integers(len(centers)))]
        x,y=np.rint(rng.normal(center,[37,34])).astype(int)
        if not (40<x<2584 and 80<y<2120):continue
        if road_clearance([x,y])<8:continue
        if any(overlaps([x-5,y-9,x+5,y+3],b,8) for b in fixed):continue
        if any(math.dist([x,y],p)<15 for p in plants):continue
        if any(math.dist([x,y],p)<24 for p in positions):continue
        plants.append([int(x),int(y)])
        plan.append({**n,'position':[int(x),int(y)],'theme':'NativePlants'})
        break
    else:raise AssertionError('plant placement exhausted')
assert len(plan)==len(trees)+len(slots)
for n,slot in zip(plan[len(trees):len(trees)+119],slots[:119]):
    n['uid']=slot['uid']
    n['replaces']=slot['name']
original_refs={n['kind']:n['ref'] for n in nodes}
used={n['kind'] for n in plan}
new_refs={k:'s32_'+k for k in sorted(used) if k not in original_refs}
text=re.sub(r'^\[ext_resource type="PackedScene" path="[^"\n]*/stage32/[^"\n]+" id="s32_[^"]+"\]\n','',text,flags=re.M)
resources=''.join(f'[ext_resource type="PackedScene" path="res://scenes/objects/krivaya_sosna/stage32/{k}.tscn" id="{ref}"]\n' for k,ref in new_refs.items())
offset=text.index('[sub_resource')
text=text[:offset].rstrip()+'\n'+resources+'\n'+text[offset:]
for n in plan:
    ref=original_refs.get(n['kind'],new_refs.get(n['kind']))
    pattern=rf'\[node name="[^"\n]+"[^\n]*unique_id={n["uid"]}[^\n]*\]\nposition = Vector2\([^\n]+\)'
    match=re.search(pattern,text)
    assert match,(n['name'],n['uid'])
    block=match[0]
    block=re.sub(r'name="[^"]+"',f'name="{n["name"]}"',block,count=1)
    block=re.sub(r'parent="[^"]+"',f'parent="{n["parent"]}"',block,count=1)
    block=re.sub(r'instance=ExtResource\("[^"]+"\)',f'instance=ExtResource("{ref}")',block)
    x,y=n['position']
    block=re.sub(r'position = Vector2\([^\n]+\)',f'position = Vector2({int(x)}, {int(y)})',block)
    text=text[:match.start()]+block+text[match.end():]
# Reparented instances must follow their parent declarations in PackedScene.
# Keep the original groups and append the static detail roots after those groups.
detail_blocks=[]
def collect_detail(match):
    detail_blocks.append(match[0])
    return ''
text=re.sub(r'^\[node name="S32_[^\n]+\]\n.*?(?=^\[|\Z)',collect_detail,text,flags=re.M|re.S)
assert len(detail_blocks)==119
marker=text.find('[editable ')
marker=len(text) if marker<0 else marker
text=text[:marker].rstrip()+'\n\n'+''.join(detail_blocks)+'\n'+text[marker:]
assert len(re.findall(r'instance=ExtResource',text))==len(re.findall(r'instance=ExtResource',SCENE.read_text()))
old_tiles=re.findall(r'tile_map_data = [^\n]+',SCENE.read_text())
assert re.findall(r'tile_map_data = [^\n]+',text)==old_tiles
text=text.replace('title = "Дом плотника"','title = "Дом охотника"')
SCENE.write_text(text.rstrip()+'\n')
(OUT/'layout.json').write_text(json.dumps({'seed':3206046,'base_scene_terrain_sha256':[hashlib.sha256(s.encode()).hexdigest() for s in old_tiles],'trees':len(trees),'reused_plant_slots':len(slots),'new_detail_instances':119,'native_plants':74,'changes':plan},ensure_ascii=False,indent=2)+'\n')
print('Detailed existing map:',len(trees),'trees redistributed;',119,'plant slots repurposed;',74,'native plants retained; terrain bytes unchanged')
