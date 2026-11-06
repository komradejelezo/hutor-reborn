"""Apply Stage 4.2 to the approved scene without repacking its saved layers.
Requires Git history at the approved base and generated Stage 4.2 resources.
No runtime generation. Existing building/pine transforms and gameplay are frozen.
"""
from pathlib import Path
import subprocess
import json
import math
import random
import re

P=Path(__file__).resolve().parents[1]
B=P/'assets/environment/krivaya_sosna'
OUT=B/'stage42'
BASE='01131ddfb63ceef1f6ad77c6d2ecb2c5bde1f79a'
text=subprocess.check_output(['git','show',BASE+':HutorReborn/scenes/world/krivaya_sosna/krivaya_sosna.tscn'],cwd=P.parent).decode()
plan=json.loads((OUT/'layout.json').read_text())
refs={path:key for path,key in re.findall(r'path="([^"]+)" id="([^"]+)"',text)}
new_refs=[]
def ref(path):
 path='res://'+path
 if path not in refs:
  key='s42_'+str(len(new_refs));refs[path]=key
  new_refs.append('[ext_resource type="PackedScene" path="%s" id="%s"]\n'%(path,key))
 return refs[path]
def asset(kind):
 if kind in ['inn','abandoned_house','hitching_rail','medicinal_garden']:
  return ref('scenes/objects/krivaya_sosna/stage42/'+kind+'.tscn')
 regular=P/'scenes/objects/krivaya_sosna'/(kind+'.tscn')
 return ref('scenes/objects/krivaya_sosna/'+('' if regular.exists() else 'stage32/')+kind+'.tscn')
def set_value(body,key,value):
 regex=r'^'+re.escape(key)+r' = [^\n]+$'
 return re.sub(regex,key+' = '+value,body,flags=re.M) if re.search(regex,body,re.M) else body.rstrip()+'\n'+key+' = '+value+'\n\n'
def point(p):return 'Vector2(%s, %s)'%tuple(p)
blocks=re.findall(r'^(\[node[^\n]+\])\n(.*?)(?=^\[|\Z)',text,re.M|re.S)
roles={
 'ElderHouse':('elder','Дом старосты',['Староста'],'Самый крепкий сруб в хуторе. У порога аккуратно сложены дрова.'),
 'MillerHouse':('woodcutter','Дом семьи дровосека',['Дровосек','Жена дровосека','Сын дровосека'],'Здесь живёт семья дровосека. Во дворе — колода, топоры и пахнущие смолой поленья.'),
 'CommonHouse':('storehouse','Общий склад',[],'Общий запас хутора: зерно, мешки, бочки и ящики под надёжной крышей.'),
 'CarpenterHouse':('old_man','Дом старика',['Старик'],'Скромный жилой дом самого старого жителя хутора. У стены стоит потёртая скамья.'),
 'HerbalistHouse':('herbalist','Дом травницы и её брата',['Травница','Брат травницы'],'Ветхая крыша покосилась, но дом обитаем. На старых перекладинах сохнут лекарственные травы.'),
}
relocations=[]
changes={}
stock_positions=iter([(1124,1250),(1165,1277),(1452,1235),(1442,1277),(1484,1247),(1117,1214),(1150,1187),(1475,1190)])
inn_kitchen={'cooking_tripod':(1830,2370),'kitchen_pot':(1885,2330),'wash_basin':(1920,2370),'tankard':(1750,2345),'wood_trough':(1955,2290)}
tree_candidates=[]
objects=[]
inverse={v:k for k,v in refs.items()}
for header,body in blocks:
 name=re.search(r'name="([^"]+)"',header)[1]
 parent_match=re.search(r'parent="([^"]*)"',header);parent=parent_match[1] if parent_match else ''
 pos=re.search(r'^position = Vector2\(([^,]+), ([^)]+)\)',body,re.M)
 location=[float(pos[1]),float(pos[2])] if pos else [0,0]
 instance=re.search(r'instance=ExtResource\("([^"]+)"\)',header)
 path=inverse.get(instance[1],'') if instance else ''
 kind=Path(path).stem
 objects.append({'name':name,'parent':parent,'kind':kind,'position':location})
 if parent=='Actors/Structures' and name in roles:
  role,title,residents,description=roles[name]
  body=set_value(body,'metadata/building_role',json.dumps(role))
  body=set_value(body,'metadata/residents','PackedStringArray('+', '.join(json.dumps(s,ensure_ascii=False) for s in residents)+')')
 if name=='InteractionPoint' and parent.split('/')[-1] in roles:
  role,title,residents,description=roles[parent.split('/')[-1]]
  body=set_value(body,'title',json.dumps(title,ensure_ascii=False));body=set_value(body,'description',json.dumps(description,ensure_ascii=False))
 if name=='KrivayaSosna':body=set_value(body,'map_size','Vector2i(2976, 2560)')
 if name=='HUD':
  body=set_value(body,'location_subtitle',json.dumps('Семь строений. Тихий хутор у леса.',ensure_ascii=False))
  body=set_value(body,'pause_caption',json.dumps('Кривая Сосна · семь строений',ensure_ascii=False))
 if name.startswith('S32_Miller_'):
  new=next(stock_positions)
  body=set_value(body,'position',point(new));relocations.append({'name':name,'from':location,'to':new,'reason':'former milling supplies moved to common storehouse'})
 if name.startswith('S32_Common_'):
  for k,new in inn_kitchen.items():
   if name.startswith('S32_Common_'+k+'_'):
    body=set_value(body,'position',point(new));relocations.append({'name':name,'from':location,'to':new,'reason':'cooking equipment moved from warehouse to inn'})
 if name.startswith('S32_Hunter_hide_rack_'):
  header=re.sub(r'instance=ExtResource\("[^"]+"\)','instance=ExtResource("'+asset('short_bench')+'")',header)
  body=set_value(body,'metadata/repurposed','"old_man_bench"')
 if name.startswith('S32_Hunter_axe_stump_') or name.startswith('S32_Hunter_saw_'):
  new=(1625,785) if 'axe_stump' in name else (1595,818)
  body=set_value(body,'position',point(new));relocations.append({'name':name,'from':location,'to':new,'reason':'working tools reassigned to woodcutter'})
 original_header = next(h for h,b in blocks if re.search(r'name="([^"]+)"',h)[1]==name and (re.search(r'parent="([^"]*)"',h)[1] if re.search(r'parent="([^"]*)"',h) else '')==parent)
 if name=='Garden104':
  header=re.sub(r'instance=ExtResource\("[^"]+"\)','instance=ExtResource("'+asset('medicinal_garden')+'")',header)
 changes[original_header]=(header,body)

def clearance(p):
 result=1e6
 for road in plan['roads']:
  for a,b in zip(road['points'],road['points'][1:]):
   dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/max(dx*dx+dy*dy,1)))
   result=min(result,math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)-road['radius'])
 return result
def clearing(p):
 x,y=p
 # Account for the 270px tree canopy above a trunk, not just its collision.
 return (1310<x<2070 and 1900<y<2660) or (2490<x<2930 and 730<y<1375) or clearance(p)<42
rng=random.Random(420711)
tree_positions=[n['position'] for n in objects if ('pine_' in n['kind'] or 'mixed_tree' in n['kind']) and not clearing(n['position'])]
def forest_spot():
 for _ in range(10000):
  if rng.random()<.53:p=[rng.randrange(70,2910),rng.randrange(2200,2528)]
  else:p=[rng.randrange(2665,2930),rng.randrange(160,2528)]
  if clearing(p) or any(math.dist(p,q)<60 for q in tree_positions):continue
  tree_positions.append(p);return p
 raise RuntimeError('New forest slots exhausted')
for n in objects:
 is_tree='pine_' in n['kind'] or 'mixed_tree' in n['kind']
 # Construction clears only the new wings/trail; never the landmark tree.
 if n['parent']=='Actors/Nature' and is_tree and clearing(n['position']):
  new=forest_spot();old_header=next(h for h,b in blocks if 'name="'+n['name']+'"' in h)
  header,body=changes[old_header];body=set_value(body,'position',point(new));changes[old_header]=(header,body)
  relocations.append({'name':n['name'],'from':n['position'],'to':new,'reason':'trees retained on the extended forest perimeter'})

def replace_node(match):
 h,b=changes[match[1]];return h+'\n'+b
text=re.sub(r'^(\[node[^\n]+\])\n(.*?)(?=^\[|\Z)',replace_node,text,flags=re.M|re.S)
# A derived scene darkens only the existing art. Crooked roof, scale and physics remain.
text=text.replace('path="res://scenes/objects/krivaya_sosna/herbalist_house.tscn"','path="res://scenes/objects/krivaya_sosna/stage42/herbalist_weathered.tscn"')
# Reuse the exact original bounds resources; change their authored dimensions.
text=text.replace('size = Vector2(2688, 32)','size = Vector2(3040, 32)').replace('size = Vector2(32, 2176)','size = Vector2(32, 2560)')
for before,after in [('Vector2(1312, -16)','Vector2(1488, -16)'),('Vector2(1312, 2192)','Vector2(1488, 2576)'),('Vector2(-16, 1088)','Vector2(-16, 1280)'),('Vector2(2640, 1088)','Vector2(2992, 1280)')]:text=text.replace('position = '+before,'position = '+after)
layers=''
for name,path in [('Extension Ground','extension_ground'),('New Paths','new_paths')]:
 key=ref('scenes/world/krivaya_sosna/stage42/'+path+'.tscn')
 layers+='[node name="%s" parent="." instance=ExtResource("%s")]\n\n'%(name,key)
index=text.index('[node name="Ground Objects"')
text=text[:index]+layers+text[index:]

added=[]
def add(name,kind,p,parent='Actors/Props',metadata=''):
 key=asset(kind);added.append({'name':name,'kind':kind,'position':list(p),'parent':parent})
 return '[node name="%s" parent="%s" instance=ExtResource("%s")]\nposition = %s\n%s\n'%(name,parent,key,point(p),metadata)
append=''
append+=add('Inn','inn',(1688,2264),'Actors/Structures')
append+=add('AbandonedHouse','abandoned_house',(2700,1030),'Actors/Structures','metadata/building_role = "abandoned"\nmetadata/residents = PackedStringArray()')
for name,role in roles.items():
 p=(-22,15) if name=='HerbalistHouse' else ((0,15) if name=='CommonHouse' else (24,15))
 append+='[node name="Entrance" type="Marker2D" parent="Actors/Structures/%s"]\nposition = %s\nmetadata/interior_id = "%s"\nmetadata/transition_enabled = false\n\n'%(name,point(p),role[0])
items={
 'Woodcutter':[('wood_store',(1805,790)),('logs',(1586,767)),('axe_stump',(1837,840)),('chips',(1600,786)),('bark',(1845,811)),('short_bench',(1580,850)),('bucket',(1777,828))],
 'Storehouse':[('crate',(1090,1270)),('barrel',(1490,1290)),('grain_sack',(1414,1260)),('crate',(1454,1140)),('sack_tied',(1108,1175))],
 'OldMan':[('bucket',(786,1662)),('broom',(934,1617)),('wood_store',(687,1650)),('basket',(905,1676))],
 'Herbalist':[('herb_line',(1900,1588)),('herb_pot',(1590,1694)),('herb_pot',(1630,1715)),('white_herbs',(1677,1700)),('white_herbs',(1585,1657)),('bush_sparse',(1900,1662)),('bush_sparse',(1570,1600)),('leaf_litter',(1890,1625)),('bark',(1612,1590))],
 'Inn':[('hitching_rail',(1460,2390)),('cart',(1935,2375)),('barrel',(1900,2310)),('barrel',(1960,2325)),('crate',(1445,2348)),('bench',(1620,2365)),('basket',(1800,2340)),('logs',(1950,2200)),('wood_store',(1385,2300)),('hanging_lantern',(1778,2318))],
 'Abandoned':[('fence_broken',(2590,1140)),('fence_broken',(2825,1095)),('branches',(2600,1010)),('dry_snag',(2865,1115)),('old_stump',(2580,935)),('bush_sparse',(2780,1065)),('bush_sparse',(2620,1050)),('leaf_litter',(2720,1120)),('bark',(2650,1080)),('branches',(2800,1000))],
}
for theme,entries in items.items():
 for i,(kind,p) in enumerate(entries):
  parent='Ground Objects' if kind in ['chips','bark','leaf_litter','branches','white_herbs'] else 'Actors/Props'
  append+=add('S42_'+theme+'_'+kind+'_'+str(i),kind,p,parent)
for i in range(58):append+=add('S42_Forest_'+str(i),'pine_'+str(i%4),forest_spot(),'Actors/Nature')
for i in range(38):
 p=forest_spot()
 append+=add('S42_Undergrowth_'+str(i),['shrub','bush_sparse','branches','leaf_litter','old_stump','roots'][i%6],p,'Ground Objects' if i%6 in [2,3,5] else 'Actors/Nature')
append+='[node name="Future NPC Space" type="Node2D" parent="."]\n\n'
reserved={'Square':(1378,1442),'Pine':(560,917),'Woodcutter':(1713,810),'Herbalist':(1717,1660),'Inn':(1688,2325),'Elder':(936,805)}
for name,p in reserved.items():append+='[node name="%s" type="Marker2D" parent="Future NPC Space"]\nposition = %s\nmetadata/clear_radius = 24.0\n\n'%(name,point(p))
text=text.rstrip()+'\n\n'+append
i=text.index('[sub_resource');text=text[:i]+''.join(new_refs)+'\n'+text[i:]
scene=P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn';scene.write_text(text.rstrip()+'\n')
(OUT/'placements.json').write_text(json.dumps({'base':BASE,'relocations':relocations,'added':added,'reserved':reserved,'building_roles':roles},ensure_ascii=False,indent=2)+'\n')
print('Updated roles; kept all five house/landmark positions; relocated',len(relocations),'existing items/trees;',len(added),'additions')
