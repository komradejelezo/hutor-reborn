"""Brother-only scope, preserved schedules and whole-pose alpha/atlas integrity."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];R=P.parent;BASE='b63f185';B=P/'assets/npc/herbalist_brother5411'
def old(p):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+p],cwd=R)
allowed={'data/visuals/animation_catalog.json','data/visuals/residents.json','dialogues/residents/herbalist_brother.json','scenes/npc/residents/herbalist_brother.tscn','scenes/interiors/herbalist.tscn','scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd'}
changed=set(subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines());changed.update(subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=R,text=True).splitlines())
for p in changed:
 if p.startswith('HutorReborn/'):
  n=p[len('HutorReborn/'):];assert n in allowed or n.startswith('assets/npc/herbalist_brother5411/') or n in ['scripts/npc/rework/brother_presentation_5411.gd','scripts/npc/rework/brother_presentation_5411.gd.uid'] or (n.startswith(('tools/','tests/')) and '5411' in n),p
 else:assert p=='HERBALIST_BROTHER_REWORK_5_4_11.md' or p.startswith('deliverables/Stage5411/'),p
for p in ['data/visuals/animation_catalog.json','data/visuals/residents.json']:
 a=json.loads(old(p));b=json.loads((P/p).read_text());assert {k:v for k,v in a.items() if k!='herbalist_brother'}=={k:v for k,v in b.items() if k!='herbalist_brother'}
for p in ['data/life/residents/herbalist_brother.json','assets/npc/stage43/herbalist_brother/definition.tres','scripts/npc/npc.gd','scripts/npc/npc_animator.gd','scripts/npc/rework/work_bindings.gd','scripts/life/village_life.gd','scenes/npc/resident.tscn']:assert (P/p).read_bytes()==old(p),p
p='dialogues/residents/herbalist_brother.json';assert (P/p).read_bytes()==old(p).replace(b'res://assets/npc/stage54/game/herbalist_brother/portraits/',b'res://assets/npc/herbalist_brother5411/game/portraits/')
for p in ['scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd']:
 s=(P/p).read_text()
 if p.endswith('visual_library.gd'):s=s.replace('        if id==&"herbalist_brother":path="res://assets/npc/herbalist_brother5411/game/frames.tres"\n','')
 elif p.endswith('activity_presenter.gd'):s=s.replace('    if resident.id==&"herbalist_brother":visual54=preload("res://scripts/npc/rework/brother_presentation_5411.gd").new()\n','')
 else:s=s.replace(' or path.begins_with("res://assets/npc/herbalist_brother5411/game/portraits/")','')
 assert s.encode()==old(p),'shared registration exceeded '+p
p='scenes/interiors/herbalist.tscn';s=(P/p).read_text()
s=re.sub(r'\[ext_resource type="Texture2D"[^\n]+id="B5411_(?:stump|axe|log)"\]\n','',s)
s=re.sub(r'\[sub_resource type="RectangleShape2D" id="B5411_feet"\]\nsize = Vector2\(12, 8\)\n\n','',s)
s=re.sub(r'\[node name="BrotherWorkBlock5411".*?(?=\[node name="Residents")','',s,flags=re.S)
s=s.replace('\n\n\n[sub_resource','\n\n[sub_resource');assert s.encode()==old(p),'existing room altered'
m=json.loads((B/'manifest.json').read_text());a=Image.open(B/'game/atlas.png').convert('RGBA');frames=[]
for v in m['sources'].values():assert hashlib.sha256((B/'source'/v['file']).read_bytes()).hexdigest()==v['sha256']
for i,r in enumerate(m['frames']):
 f=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=f.getbbox();n=np.array(f)
 assert box and min(box)>0 and max(box)<96 and set(np.unique(n[:,:,3]))<={0,255}
 assert np.all(n[n[:,:,3]==0]==0) and r['pivot']==[48,82];frames.append(f)
for d in ['right','left','down','up']:
 ids=m['clips']['walk_'+d];assert len(ids)==6 and len({frames[i].tobytes() for i in ids})==6
assert not np.array_equal(np.array(frames[m['clips']['walk_left'][0]]),np.array(frames[m['clips']['walk_right'][0]])[:,::-1])
for name,count in [('chop_wood',8),('split_logs',8),('think',4),('tired_idle',4)]:
 ids=m['clips'][name];assert len(ids)==count and len({frames[i].tobytes() for i in ids})==count
 assert len({m['frames'][i]['scale_uniform'] for i in ids})==1,'proportions change '+name
assert not any(k.startswith(('run_','carry_')) for k in m['clips'])
assert not subprocess.check_output(['git','diff','--name-only','--diff-filter=D',BASE],cwd=R)
for p in changed:
 if p.endswith('.gd'):
  s=(R/p).read_text();assert not re.search(r'^(<<<<<<<|=======|>>>>>>>)',s,re.M);names=re.findall(r'^func (\w+)\(',s,re.M);assert len(names)==len(set(names)),p
print('PASS: brother-only graphics; all eight other profiles, original schedules, dialogue texts, speed37, core NPC/animator and old room nodes/collisions preserved; source hashes, whole uniform poses, binary alpha, unique gaits and independent left')
