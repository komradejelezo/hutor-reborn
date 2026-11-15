"""Preserve all eight other residents and the world; check source/atlas integrity."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];R=P.parent;BASE='4b8346d';B=P/'assets/npc/old_man549'
def old(p):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+p],cwd=R)
allowed={'data/visuals/animation_catalog.json','data/visuals/residents.json','dialogues/residents/old_man.json','scenes/npc/residents/old_man.tscn','scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd'}
changed=subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines()
for p in changed:
 if p.startswith('HutorReborn/'):
  n=p[len('HutorReborn/'):];assert n in allowed or n.startswith('assets/npc/old_man549/') or n in ['scripts/npc/rework/old_man_presentation_549.gd','scripts/npc/rework/old_man_presentation_549.gd.uid'] or (n.startswith(('tools/','tests/')) and '549' in n),p
 else:assert p=='OLD_MAN_REWORK_5_4_9.md' or p.startswith('deliverables/Stage549/'),p
for p in ['data/visuals/animation_catalog.json','data/visuals/residents.json']:
 a=json.loads(old(p));b=json.loads((P/p).read_text());assert {k:v for k,v in a.items() if k!='old_man'}=={k:v for k,v in b.items() if k!='old_man'}
for p in ['data/life/residents/old_man.json','assets/npc/stage43/old_man/definition.tres','scripts/npc/npc.gd','scripts/npc/npc_animator.gd','scripts/npc/rework/work_bindings.gd','scripts/life/village_life.gd','scenes/npc/resident.tscn']:assert (P/p).read_bytes()==old(p),p
p='dialogues/residents/old_man.json';assert (P/p).read_bytes()==old(p).replace(b'res://assets/npc/stage54/game/old_man/portraits/',b'res://assets/npc/old_man549/game/portraits/')
for p in ['scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd']:
 s=(P/p).read_text()
 if p.endswith('visual_library.gd'):s=s.replace('        if id==&"old_man":path="res://assets/npc/old_man549/game/frames.tres"\n','')
 elif p.endswith('activity_presenter.gd'):s=s.replace('    if resident.id==&"old_man":visual54=preload("res://scripts/npc/rework/old_man_presentation_549.gd").new()\n','')
 else:s=s.replace(' or path.begins_with("res://assets/npc/old_man549/game/portraits/")','')
 assert s.encode()==old(p),'shared change exceeds old-man registration: '+p
m=json.loads((B/'manifest.json').read_text());a=Image.open(B/'game/atlas.png').convert('RGBA');frames=[]
for v in m['sources'].values():assert hashlib.sha256((B/'source'/v['file']).read_bytes()).hexdigest()==v['sha256']
for i,r in enumerate(m['frames']):
 f=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=f.getbbox();n=np.array(f)
 assert box and min(box)>0 and max(box)<96 and set(np.unique(n[:,:,3]))<={0,255}
 assert np.all(n[n[:,:,3]==0]==0) and r['pivot']==[48,82];frames.append(f)
for d in ['right','left','down','up']:
 ids=m['clips']['walk_'+d];assert len(ids)==6 and len({frames[i].tobytes() for i in ids})==6
assert m['clips']['walk_left']!=m['clips']['walk_right']
assert not np.array_equal(np.array(frames[m['clips']['walk_left'][0]]),np.array(frames[m['clips']['walk_right'][0]])[:,::-1])
assert m['clips']['stand_up']==m['clips']['sit_down'][::-1]
assert 31<m['seated_height']<38
assert not subprocess.check_output(['git','diff','--name-only','--diff-filter=D',BASE],cwd=R)
print('PASS: only old-man visual scope; all other eight profiles, core NPC/animator, full original schedule, dialogue texts, scenes and world preserved; original speed18; whole frames, binary alpha, source hashes, independent left gait, unscaled seating trajectory')
