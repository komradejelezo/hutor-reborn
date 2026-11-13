"""Protect approved worlds, Hans and other eight residents; audit authoring assets."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];P=R/'HutorReborn';BASE='08c9d04'
def old(path):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+path],cwd=R)
allowed={'data/life/residents/innkeeper.json','data/visuals/animation_catalog.json','data/visuals/residents.json','dialogues/residents/innkeeper.json','scenes/interiors/inn.tscn','scenes/npc/residents/innkeeper.tscn','scripts/dialogue/dialogue_window.gd','scripts/life/activity_presenter.gd','scripts/npc/npc_animator.gd','scripts/npc/visuals/visual_library.gd'}
paths=subprocess.check_output(['git','ls-tree','-rz','--name-only',BASE,'HutorReborn'],cwd=R,text=True).strip('\0').split('\0');count=0
changed=set(subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines());assert changed.intersection(paths)<={'HutorReborn/'+p for p in allowed}
for path in paths:
 name=path.removeprefix('HutorReborn/')
 if name in allowed:continue
 assert (R/path).read_bytes()==subprocess.check_output(['git','show',BASE+':'+path],cwd=R),path
 count+=1
for path in ['data/visuals/animation_catalog.json','data/visuals/residents.json']:
 before=json.loads(old(path));after=json.loads((P/path).read_text());assert all(after[k]==v for k,v in before.items() if k!='innkeeper')
path='dialogues/residents/innkeeper.json';assert (P/path).read_text()==old(path).decode().replace('res://assets/npc/stage54/game/innkeeper/portraits/','res://assets/npc/innkeeper546/game/portraits/')
path='data/life/residents/innkeeper.json';before=json.loads(old(path));after=json.loads((P/path).read_text())
assert after['id']==before['id'] and after['home']==before['home']
assert [b['start'] for b in before['blocks']]==[b['start'] for b in after['blocks']]
for a,b in zip(before['blocks'],after['blocks']):
 assert a['scene']==b['scene'] and sum(x['minutes'] for x in a['activities'])==sum(x['minutes'] for x in b['activities'])
 for action in a['activities']:
  new=next(v for v in b['activities'] if v['id']==action['id']);assert {k:v for k,v in new.items() if k!='minutes'}=={k:v for k,v in action.items() if k!='minutes'}
# Inn scene has only five added decoration nodes and four resource declarations.
path='scenes/interiors/inn.tscn';scene=(P/path).read_text()
scene=re.sub(r'\[ext_resource[^\n]*id="546_[^\n]*\n','',scene)
scene=re.sub(r'\[node name="(?:CookingCrock546|MugWipe546|MugService546|Pitcher546|Cloth546)"[^\n]*\n.*?(?=\[|\Z)','',scene,flags=re.S)
scene=scene.replace('size = Vector2(226, 14)','size = Vector2(226, 30)').replace('[node name="Feet" parent="Actors/Props/Counter/Solid" index="0"]\nposition = Vector2(0, -7)','[node name="Feet" parent="Actors/Props/Counter/Solid" index="0"]\nposition = Vector2(0, -13)')
assert [x for x in scene.splitlines() if x.strip()]==[x for x in old(path).decode().splitlines() if x.strip()]
b=P/'assets/npc/innkeeper546';m=json.loads((b/'manifest.json').read_text());atlas=Image.open(b/'game/atlas.png').convert('RGBA');a=np.asarray(atlas)
assert set(np.unique(a[:,:,3]))=={0,255} and np.all(a[a[:,:,3]==0]==0)
for v in m['sources'].values():assert hashlib.sha256((b/'source'/v['file']).read_bytes()).hexdigest()==v['sha256']
digests=[]
for i,r in enumerate(m['frames']):
 im=atlas.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=im.getbbox();assert box and min(box)>0 and max(box)<96,(i,box)
 digests.append(hashlib.sha256(im.tobytes()).hexdigest())
assert len(set(digests))==len(digests)
for d in ['down','up','left','right']:assert len(set(m['clips']['walk_'+d]))==6
assert not subprocess.check_output(['git','diff','--diff-filter=D','--name-only',BASE],cwd=R)
print('PASS:',count,'old files unchanged; other eight models, schedules, profiles and animations unchanged')
print('PASS: inn scene adds five small decoration nodes and corrects only counter base collision; all other nodes and navigation unchanged')
print('PASS: innkeeper block boundaries and cycle totals retained; original points/activities retained')
print('PASS:',len(digests),'unique native poses; full frames, binary alpha, source hashes and six-phase gaits')
