"""Source/scope invariants, not a substitute for visual motion review."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];R=P.parent;BASE='3de107b';B=P/'assets/npc/elder548'
def old(path):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+path],cwd=R)
for path in ['data/visuals/residents.json','data/visuals/animation_catalog.json']:
 a=json.loads(old(path));b=json.loads((P/path).read_text());assert {k:v for k,v in a.items() if k!='elder'}=={k:v for k,v in b.items() if k!='elder'}
a=json.loads(old('data/life/residents/elder.json'));b=json.loads((P/'data/life/residents/elder.json').read_text())
assert a['home']==b['home'] and a['id']==b['id']
for x,y in zip(a['blocks'],b['blocks']):
 assert x['start']==y['start'] and x['scene']==y['scene']
 assert sum(v['minutes'] for v in x['activities'])==sum(v['minutes'] for v in y['activities'])
 if x['scene']=='village':assert [v['point'] for v in x['activities']]==[v['point'] for v in y['activities']]
path='dialogues/residents/elder.json';assert (P/path).read_bytes()==old(path).replace(b'res://assets/npc/stage54/game/elder/portraits/',b'res://assets/npc/elder548/game/portraits/')
def blocks(text):return {v.splitlines()[0]:v.strip() for v in re.split(r'(?=^\[)',text,flags=re.M) if v.startswith('[')}
a=blocks(old('scenes/interiors/elder.tscn').decode());b=blocks((P/'scenes/interiors/elder.tscn').read_text())
for k,v in a.items():assert b[k]==v,'old room block changed: '+k
allowed={'data/life/residents/elder.json','data/visuals/residents.json','data/visuals/animation_catalog.json','dialogues/residents/elder.json','scenes/interiors/elder.tscn','scenes/npc/residents/elder.tscn','scripts/dialogue/dialogue_window.gd','scripts/life/activity_presenter.gd','scripts/npc/npc_animator.gd','scripts/npc/rework/work_bindings.gd','scripts/npc/visuals/visual_library.gd'}
paths=subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines()
for path in paths:
 if path.startswith('HutorReborn/'):
  name=path[len('HutorReborn/'):];assert name in allowed or name.startswith('assets/npc/elder548/') or name=='scripts/npc/rework/elder_presentation_548.gd' or name=='scripts/npc/rework/elder_presentation_548.gd.uid' or (name.startswith(('tests/','tools/')) and '548' in name),path
 else:assert path=='VILLAGE_ELDER_REWORK_5_4_8.md' or path.startswith('deliverables/Stage548/'),path
m=json.loads((B/'manifest.json').read_text());atlas=Image.open(B/'game/atlas.png').convert('RGBA');frames=[]
for s in m['sources'].values():assert hashlib.sha256((B/'source'/s['file']).read_bytes()).hexdigest()==s['sha256']
for i,record in enumerate(m['frames']):
 f=atlas.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=f.getbbox();a=np.array(f)
 assert box and min(box)>0 and max(box)<96 and set(np.unique(a[:,:,3]))<={0,255}
 assert np.all(a[a[:,:,3]==0]==0) and record['pivot']==[48,82]
 frames.append(f)
for d in ['down','up','left','right']:
 ids=m['clips']['walk_'+d];assert len(ids)==6 and len({hashlib.sha256(frames[i].tobytes()).hexdigest() for i in ids})==6
assert m['clips']['walk_left']==m['clips']['walk_right']
p='scripts/npc/npc_animator.gd';s=(P/p).read_text().replace(' or int(sprite.sprite_frames.get_meta("elder_version",0))==548','');assert s.encode()==old(p)
assert not subprocess.check_output(['git','diff','--diff-filter=D','--name-only',BASE],cwd=R)
print('PASS: elder-only scope; other eight profiles/resources untouched; old room blocks and collisions exact; original dialogue content; day boundaries/cycle totals/outdoor points; source hashes; binary clean alpha; whole 96px frames and common feet; six distinct gait phases and one left reflection')
