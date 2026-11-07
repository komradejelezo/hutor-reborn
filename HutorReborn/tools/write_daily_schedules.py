"""Author the nine daily profiles; no scene, prior NPC data or dialogue is edited."""
from pathlib import Path
import json
P=Path(__file__).resolve().parents[1]
OUT=P/'data/life';(OUT/'residents').mkdir(parents=True,exist_ok=True)
def act(id,point,minutes=8,clip='',facing='down',**extra):
    return dict(id=id,point=point,minutes=minutes,clip=clip,facing=facing,**extra)
def block(hour,scene,activities,label=''):
    return dict(start=int(hour*60),scene=scene,label=label,activities=activities)
def person(id,home,blocks,**extra):
    data=dict(id=id,home=home,blocks=sorted(blocks,key=lambda x:x['start']),**extra)
    (OUT/'residents'/(id+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
night=lambda point:[act('rest_night',point,25)]
job=[act('chop',None,12,'work_chop'),act('carry_wood',None,8),act('work_break',None,10)]
person('woodcutter','woodcutter',[
 block(0,'woodcutter',night('NPCPoints/FatherRest')),
 block(6,'woodcutter',[act('take_tool',[648,350],8),act('prepare_work','NPCPoints/FatherRest',6)]),
 block(7.5,'village',[act('meet_worker',[1368,920],12,partner='herbalist_brother')]),
 block(8,'logging',job,'Лесозаготовки'),
 block(18,'woodcutter',[act('rest_after_work','NPCPoints/FatherRest',18),act('family_meal',[516,308],10)]),
 block(22,'woodcutter',night([360,322]))],portal_lane=-10,work_group='logging_pair',work_location='logging')
person('herbalist_brother','herbalist',[
 block(0,'herbalist',night([312,358])),
 block(6,'herbalist',[act('household',[367,340],10),act('prepare_work',[480,400],8)]),
 block(7.5,'village',[act('meet_worker',[1416,920],12,partner='woodcutter')]),
 block(8,'logging',job,'Лесозаготовки'),
 block(18,'herbalist',[act('home_rest',[312,358],18),act('household',[367,340],8)]),
 block(22,'herbalist',night([312,358]))],portal_lane=10,work_group='logging_pair',work_location='logging')
person('woodcutter_wife','woodcutter',[
 block(0,'woodcutter',night([360,350])),
 block(6,'woodcutter',[act('cook',[568,296],12,'work_cook','right',hide_props=['Actors/Props/KitchenPot']),act('serve',[568,370],6)]),
 block(10,'village',[act('sweep_yard',[1800,850],10,'work_sweep','right'),act('household',[1640,875],7),act('watch_child',[1745,895],6,partner='woodcutter_son')]),
 block(12,'woodcutter',[act('cook',[568,296],12,'work_cook','right',hide_props=['Actors/Props/KitchenPot']),act('clean','NPCPoints/Housekeeping',10,'work_sweep')]),
 block(15,'village',[act('garden_work',[1800,850],10,'work_rake','right'),act('watch_child',[1745,895],8,partner='woodcutter_son')]),
 block(18,'woodcutter',[act('family_meal',[568,370],12),act('household','NPCPoints/Housekeeping',10,'work_sweep')]),
 block(22,'woodcutter',night([360,350]))])
person('woodcutter_son','woodcutter',[
 block(0,'woodcutter',night([420,324])),
 block(6,'woodcutter',[act('home_play','NPCPoints/ChildPlay',6,'work_play'),act('near_mother',[604,355],3,partner='woodcutter_wife')]),
 block(8,'village',[act('play_stick',[1685,895],7,'work_play'),act('run_yard',[1770,910],1),act('kneel_toy',[1640,840],5,'work_kneel'),act('visit_mother',[1745,865],4,partner='woodcutter_wife')]),
 block(11,'village',[act('run_to_tree',[1585,1000],1),act('play_stick',[1550,1020],6,'work_play'),act('run_path',[1480,1370],1),act('inspect_well',[1320,1580],5,'work_kneel'),act('look_at_hans',[1370,1530],3),act('return_yard',[1680,895],4,'work_play')]),
 block(15,'village',[act('play_stick',[1685,895],7,'work_play'),act('run_yard',[1770,910],1),act('kneel_toy',[1640,840],5,'work_kneel'),act('visit_mother',[1745,865],4,partner='woodcutter_wife')]),
 block(18,'woodcutter',[act('home_play','NPCPoints/ChildPlay',5,'work_play'),act('family_meal',[604,400],8)]),
 block(22,'woodcutter',night([420,324]))],safe_village_rect=[1180,740,730,970],run_multiplier=1.25)
person('herbalist','herbalist',[
 block(0,'herbalist',night([270,360])),
 block(7,'village',[act('gather',[1910,1660],10,'work_gather','right'),act('inspect_plants',[2150,1720],8,'work_inspect')]),
 block(11,'herbalist',[act('sort_herbs',[524,344],12,'work_table','right',hide_props=['Actors/Props/Table','Actors/Props/DryHerbs']),act('dry_plants',[547,213],10,'work_inspect')]),
 block(14,'village',[act('inspect_plants',[1910,1660],10,'work_inspect'),act('gather',[2150,1720],10,'work_gather','right')]),
 block(16,'herbalist',[act('brew',[524,344],15,'work_table','right',hide_props=['Actors/Props/Table','Actors/Props/DryHerbs']),act('sort_herbs',[547,213],10,'work_inspect')]),
 block(22,'herbalist',night([270,360]))])
person('innkeeper','inn',[
 block(0,'inn',night([780,220])),
 block(6,'inn',[act('prepare_inn',[456,200],10,'work_wipe',talk_offset=[0,70]),act('check_supplies',[800,360],8,'work_taste')]),
 block(10,'inn',[act('wipe_mug',[456,200],12,'work_wipe',talk_offset=[0,70]),act('arrange_dishes',[520,200],8,'work_wipe',talk_offset=[0,70])]),
 block(18,'inn',[act('wipe_mug',[456,200],12,'work_wipe',talk_offset=[0,70]),act('visit_tables',[570,440],7,'work_taste')]),
 block(22,'inn',night([780,220]))])
person('innkeeper_wife','inn',[
 block(0,'inn',night([810,310])),
 block(6,'inn',[act('kitchen',[790,365],12,'work_cook','left'),act('prepare_supplies',[770,440],8,'work_sweep')]),
 block(10,'inn',[act('clean_tables',[386,456],10,'work_sweep'),act('kitchen',[790,365],12,'work_cook','left'),act('household',[686,306],8)]),
 block(18,'inn',[act('clean_tables',[596,456],10,'work_sweep'),act('kitchen',[790,365],12,'work_cook','left')]),
 block(22,'inn',night([810,310]))])
person('elder','elder',[
 block(0,'elder',night([330,370])),
 block(6,'elder',[act('read_documents',[480,248],16,'gesture_read','right',talk_offset=[0,76]),act('ponder',[608,216],8,'gesture_think')]),
 block(10,'village',[act('inspect_square',[1378,1442],10,'gesture_think'),act('inspect_well',[1320,1580],10),act('common_store',[1287,1220],8,'gesture_read','right'),act('watch_village',[1440,1370],10)]),
 block(18,'elder',[act('read_documents',[480,248],16,'gesture_read','right',talk_offset=[0,76]),act('ponder',[608,216],10,'gesture_think')]),
 block(22,'elder',night([330,370]))])
person('old_man','old_man',[
 block(0,'old_man',night([410,390])),
 block(6,'village',[act('slow_walk',[560,917],8,'work_smoke','right'),act('sit_and_smoke',[630,1010],16,'work_sit','right'),act('ponder',[650,952],10,'work_think'),act('watch_hans',[550,945],8,'work_smoke','right')]),
 block(18,'old_man',[act('rest_by_hearth','NPCPoints/ChairRest',15,'work_smoke','right'),act('read_old_papers','NPCPoints/Reading',10,'work_think')]),
 block(22,'old_man',night([410,390]))])
(OUT/'registry.json').write_text(json.dumps({'version':1,'start_minute':420,'real_day_seconds':1800,'residents':['res://data/life/residents/'+p.name for p in sorted((OUT/'residents').glob('*.json'))]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'gateways.json').write_text(json.dumps([{'id':'north_logging','source':'village','virtual_destination':'logging','position':[1384,24],'direction':[0,-1],'outside_distance':64,'future_scene':''}],indent=2)+'\n')
print('Saved nine data-driven daily schedules and one virtual logging gateway')
