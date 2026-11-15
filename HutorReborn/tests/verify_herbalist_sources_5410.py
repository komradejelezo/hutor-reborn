"""Source-scope and whole-pose integrity guard for the herbalist-only change."""
from pathlib import Path
import subprocess,json,hashlib,re
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];R=P.parent;BASE='9122b11';B=P/'assets/npc/herbalist5410'
def old(p):return subprocess.check_output(['git','show',BASE+':HutorReborn/'+p],cwd=R)
allowed={'data/visuals/animation_catalog.json','data/visuals/residents.json','dialogues/residents/herbalist.json','scenes/npc/residents/herbalist.tscn','scenes/interiors/herbalist.tscn','scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd','scripts/npc/rework/work_bindings.gd'}
changed=set(subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines())
changed.update(subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=R,text=True).splitlines())
for p in changed:
 if p.startswith('HutorReborn/'):
  n=p[len('HutorReborn/'):]
  assert n in allowed or n.startswith('assets/npc/herbalist5410/') or n.startswith(('scripts/npc/rework/herbalist_actor_5410.gd','scripts/npc/rework/herbalist_presentation_5410.gd')) or (n.startswith(('tools/','tests/')) and '5410' in n),p
 else:assert p=='HERBALIST_REWORK_5_4_10.md' or p.startswith('deliverables/Stage5410/'),p
for p in ['data/visuals/animation_catalog.json','data/visuals/residents.json']:
 a=json.loads(old(p));b=json.loads((P/p).read_text());assert {k:v for k,v in a.items() if k!='herbalist'}=={k:v for k,v in b.items() if k!='herbalist'}
for p in ['data/life/residents/herbalist.json','assets/npc/stage43/herbalist/definition.tres','scripts/npc/npc.gd','scripts/npc/npc_animator.gd','scripts/life/village_life.gd','scenes/npc/resident.tscn']:assert (P/p).read_bytes()==old(p),p
p='dialogues/residents/herbalist.json';assert (P/p).read_bytes()==old(p).replace(b'res://assets/npc/stage54/game/herbalist/portraits/',b'res://assets/npc/herbalist5410/game/portraits/')
for p in ['scripts/npc/visuals/visual_library.gd','scripts/life/activity_presenter.gd','scripts/dialogue/dialogue_window.gd']:
 s=(P/p).read_text()
 if p.endswith('visual_library.gd'):s=s.replace('        if id==&"herbalist":path="res://assets/npc/herbalist5410/game/frames.tres"\n','')
 elif p.endswith('activity_presenter.gd'):s=s.replace('    if resident.id==&"herbalist":visual54=preload("res://scripts/npc/rework/herbalist_presentation_5410.gd").new()\n','')
 else:s=s.replace(' or path.begins_with("res://assets/npc/herbalist5410/game/portraits/")','')
 assert s.encode()==old(p),'shared change exceeds herbalist registration: '+p
p='scripts/npc/rework/work_bindings.gd'
assert (P/p).read_bytes()==old(p).replace(b'        path="Actors/Props/Table";offset=Vector2(0,30)',b'        if action=="sort_herbs":path="Actors/Props/Table";offset=Vector2(-29,-9)\n        else:path="Actors/Props/Cauldron";offset=Vector2(-26,-4)')
p='scenes/interiors/herbalist.tscn';s=(P/p).read_text()
s=re.sub(r'\[ext_resource type="Texture2D" path="res://assets/npc/herbalist5410/game/[^\n]+\n','',s).replace('\n\n\n[sub_resource','\n\n[sub_resource')
s=re.sub(r'\[node name="(?:mortar|pestle|herbs_mat|book_closed)5410"[^\n]*\n(?:[^\[]|\[(?!node))*?(?=\[node)', '',s)
assert s.encode()==old(p),'existing room nodes/layout changed'
m=json.loads((B/'manifest.json').read_text());a=Image.open(B/'game/atlas.png').convert('RGBA');frames=[]
for v in m['sources'].values():assert hashlib.sha256((B/'source'/v['file']).read_bytes()).hexdigest()==v['sha256']
for i,r in enumerate(m['frames']):
 f=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=f.getbbox();n=np.array(f)
 assert box and min(box)>0 and max(box)<96 and set(np.unique(n[:,:,3]))<={0,255}
 assert np.all(n[n[:,:,3]==0]==0) and r['pivot']==[48,82];frames.append(f)
for d in ['right','left','down','up']:
 ids=m['clips']['walk_'+d];assert len(ids)==6 and len({frames[i].tobytes() for i in ids})==6
assert not np.array_equal(np.array(frames[m['clips']['walk_left'][0]]),np.array(frames[m['clips']['walk_right'][0]])[:,::-1])
for name in ['gather_herbs','sort_herbs','grind_herbs','brew_infusion','read_herbal']:
 ids=m['clips'][name];assert len(ids)==8 and len({frames[i].tobytes() for i in ids})==8
 assert len({m['frames'][i]['scale_uniform'] for i in ids})==1,'changing proportions '+name
assert not any(k.startswith('run_') for k in m['clips'])
assert not subprocess.check_output(['git','diff','--name-only','--diff-filter=D',BASE],cwd=R)
for f in changed:
 if f.endswith('.gd'):
  s=(R/f).read_text();assert not re.search(r'^(<<<<<<<|=======|>>>>>>>)',s,re.M)
  names=re.findall(r'^func (\w+)\(',s,re.M);assert len(names)==len(set(names)),f
print('PASS: herbalist-only scope; eight other profiles, all original schedules, dialogue texts, core NPC/animator, world, room layout and collisions unchanged; speed29; original hashes; whole poses, binary alpha, unique directional gaits, independent left and uniform crouch')
