"""Scope, source provenance and authored-frame checks; not an artistic verdict."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];ROOT=P.parent;BASE='3de107b';B=P/'assets/npc/innkeeper_wife547'
def before(path):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+path],cwd=ROOT)
def old_json(path):return json.loads(before(path))
for path in ['data/visuals/residents.json','data/visuals/animation_catalog.json']:
 old=old_json(path);new=json.loads((P/path).read_text())
 assert {k:v for k,v in old.items() if k!='innkeeper_wife'}=={k:v for k,v in new.items() if k!='innkeeper_wife'},path
old=old_json('data/life/residents/innkeeper_wife.json');new=json.loads((P/'data/life/residents/innkeeper_wife.json').read_text())
assert old['home']==new['home'] and old['id']==new['id']
for a,b in zip(old['blocks'],new['blocks']):
 assert a['start']==b['start'] and a['scene']==b['scene']
 assert abs(sum(x['minutes'] for x in a['activities'])-sum(x['minutes'] for x in b['activities']))<.001
old=old_json('dialogues/residents/innkeeper_wife.json');new=json.loads((P/'dialogues/residents/innkeeper_wife.json').read_text())
def content(o):
 if isinstance(o,dict):return {k:content(v) for k,v in o.items() if k not in ['portrait','portraits']}
 if isinstance(o,list):return [content(v) for v in o]
 return o
assert content(old)==content(new),'dialogue texts/branches must not change'
def blocks(text):
 parts=re.split(r'(?=^\[)',text,flags=re.M);return {v.splitlines()[0]:v.strip() for v in parts if v.startswith('[')}
a=blocks(before('scenes/interiors/inn.tscn').decode());b=blocks((P/'scenes/interiors/inn.tscn').read_text())
for key,v in a.items():assert b[key]==v,'old inn block changed: '+key
# Immutable actor implementations, source sprites, routes, dialogue, and all other rooms.
changed=subprocess.check_output(['git','diff','--name-only',BASE],cwd=ROOT,text=True).splitlines()
allowed={'data/life/residents/innkeeper_wife.json','data/visuals/residents.json','data/visuals/animation_catalog.json','dialogues/residents/innkeeper_wife.json','scenes/interiors/inn.tscn','scenes/npc/residents/innkeeper_wife.tscn','scripts/dialogue/dialogue_window.gd','scripts/life/activity_presenter.gd','scripts/npc/npc_animator.gd','scripts/npc/rework/work_bindings.gd','scripts/npc/visuals/visual_library.gd'}
for path in changed:
 if path.startswith('HutorReborn/'):
  rel=path[len('HutorReborn/'):]
  assert rel in allowed or rel.startswith(('assets/npc/innkeeper_wife547/','tools/','tests/','scripts/npc/rework/innkeeper_wife_')),path
 else:assert path=='INNKEEPER_WIFE_REWORK_5_4_7.md' or path.startswith('deliverables/Stage547/'),path
m=json.loads((B/'manifest.json').read_text());atlas=Image.open(B/'game/atlas.png').convert('RGBA')
for v in m['sources'].values():assert hashlib.sha256((B/'source'/v['file']).read_bytes()).hexdigest()==v['sha256']
frames=[]
for i,record in enumerate(m['frames']):
 frame=atlas.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));a=np.array(frame);box=frame.getbbox()
 assert set(np.unique(a[:,:,3]))<={0,255}
 assert box and min(box)>0 and max(box)<96
 assert record['pivot']==[48,82] and record['scale_uniform']>0
 frames.append(frame)
for direction in ['down','up','right','left']:
 ids=m['clips']['walk_'+direction];assert len(ids)==6
 assert len({hashlib.sha256(frames[i].tobytes()).hexdigest() for i in ids})==6,'padded gait'
assert m['clips']['walk_left']==m['clips']['walk_right']
# The shared renderer change is strictly an additional authored-settle metadata guard.
p='scripts/npc/npc_animator.gd';s=(P/p).read_text();s=s.replace(' or int(sprite.sprite_frames.get_meta("innkeeper_wife_version",0))==547','');assert s.encode()==before(p)
print('PASS: wife-only scope, six distinct gait phases, binary alpha, source hashes, feet/canvas, original inn blocks, all other profiles, dialogue content, day boundaries and cycle totals preserved')
