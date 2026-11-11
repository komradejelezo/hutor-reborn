from pathlib import Path
import subprocess,json,hashlib,numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[2];p=r/'HutorReborn';b=p/'assets/npc/woodcutter542';m=json.loads((b/'manifest.json').read_text());a=Image.open(b/'game/atlas.png').convert('RGBA');v=np.array(a)
assert np.all(v[v[:,:,3]==0]==0)
assert set(np.unique(v[:,:,3]))=={0,255}
for key,src in m['sources'].items():assert hashlib.sha256((b/'source'/src['file']).read_bytes()).hexdigest()==src['sha256']
poses=[]
for i,frame in enumerate(m['frames']):
 c=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=c.getbbox();assert box and min(box)>0 and box[2]<96 and box[3]<96,(i,box)
 assert frame['pivot']==[48,82] and frame['scale_uniform']>0
 poses.append(hashlib.sha256(c.tobytes()).hexdigest())
assert len(set(poses))==len(poses),'duplicate padded poses'
for d in ['down','up','right','left']:assert len(m['clips']['walk_'+d])==6 and len(m['clips']['carry_'+d])==6
old=json.loads(subprocess.check_output(['git','show','4884da5:HutorReborn/data/visuals/animation_catalog.json'],cwd=r));new=json.loads((p/'data/visuals/animation_catalog.json').read_text())
assert all(new[id]==val for id,val in old.items() if id!='woodcutter')
paths=subprocess.check_output(['git','diff','--name-only','4884da5'],cwd=r,text=True).splitlines()
protected=['HutorReborn/assets/characters/','HutorReborn/scenes/','HutorReborn/data/life/','HutorReborn/data/dialogues/','HutorReborn/assets/npc/stage54','HutorReborn/assets/npc/stage541','HutorReborn/assets/audio/']
assert not any(path.startswith(tuple(protected)) for path in paths)
assert not subprocess.check_output(['git','diff','--diff-filter=D','--name-only','4884da5'],cwd=r)
print(f'PASS: {len(poses)} unique transparent poses, four-way walk/carry, safe bounds/pivots; Hans, other eight NPC resources, schedules, maps/interiors, dialogues/audio unchanged')
# Honest alpha-silhouette measurements: shoulder span is clothing, not anatomy.
for name,indices in [('idle_down',m['clips']['idle_down']),('carry_idle_down',m['clips']['carry_idle_down'])]:
 i=indices[0];c=a.crop((i%8*96,i//8*96,i%8*96+96,i//8*96+96));box=c.getbbox();ar=np.array(c)[:,:,3]>0;y0=box[1]+round((box[3]-box[1])*.22);y1=box[1]+round((box[3]-box[1])*.38);yy,xx=np.where(ar[y0:y1]);print(name,'bbox',box,'shoulder-clothing-band',y0,y1,'span',int(xx.max()-xx.min()+1))
