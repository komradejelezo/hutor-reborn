"""Protect all approved bodies/world data while auditing the new wife's atlas."""
from pathlib import Path
import subprocess,json,hashlib
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];P=R/'HutorReborn';BASE='0a48dab'
paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'HutorReborn'],cwd=R,text=True).splitlines();count=0
allowed={'HutorReborn/data/visuals/animation_catalog.json','HutorReborn/scenes/npc/residents/woodcutter_wife.tscn','HutorReborn/scripts/dialogue/dialogue_window.gd','HutorReborn/scripts/life/activity_presenter.gd','HutorReborn/scripts/npc/npc_animator.gd','HutorReborn/scripts/npc/rework/work_bindings.gd','HutorReborn/scripts/npc/visuals/visual_library.gd'}
changed=set(subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines())
assert changed.intersection(paths)<=allowed,'An unrelated existing project file changed'
for p in paths:
 protect=p.endswith(('.png','.tres','.json','.tscn','.gdshader')) or p.startswith(('HutorReborn/assets/characters/','HutorReborn/data/life/'))
 if p in ['HutorReborn/data/visuals/animation_catalog.json','HutorReborn/scenes/npc/residents/woodcutter_wife.tscn']:continue
 if protect:
  assert (R/p).read_bytes()==subprocess.check_output(['git','show',BASE+':'+p],cwd=R),p
  count+=1
old=json.loads(subprocess.check_output(['git','show',BASE+':HutorReborn/data/visuals/animation_catalog.json'],cwd=R));new=json.loads((P/'data/visuals/animation_catalog.json').read_text())
assert all(new[k]==v for k,v in old.items() if k!='woodcutter_wife')
b=P/'assets/npc/woodcutter_wife544';m=json.loads((b/'manifest.json').read_text());atlas=Image.open(b/'game/atlas.png').convert('RGBA');arr=np.asarray(atlas)
assert new['woodcutter_wife']['clips']=={k:len(v) for k,v in m['clips'].items()}
assert set(np.unique(arr[:,:,3]))=={0,255};assert np.all(arr[arr[:,:,3]==0]==0)
for key,s in m['sources'].items():assert hashlib.sha256((b/'source'/s['file']).read_bytes()).hexdigest()==s['sha256']
frames=[]
for i,r in enumerate(m['frames']):
 im=atlas.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=im.getbbox()
 assert box and min(box)>0 and box[2]<96 and box[3]<96,(i,box)
 frames.append(hashlib.sha256(im.tobytes()).hexdigest())
assert len(set(frames))==len(frames)
for d in ['down','up','left','right']:
 assert len(m['clips']['walk_'+d])==6 and len(set(m['clips']['walk_'+d]))==6
 assert 'idle_'+d in m['clips']
assert not subprocess.check_output(['git','diff','--diff-filter=D','--name-only',BASE],cwd=R)
print(f'PASS: {count} protected old files unchanged; other eight animation records unchanged')
print(f'PASS: {len(frames)} unique poses; {len(m["clips"])} compatible names; full frames, alpha, hashes and four six-phase gaits')
