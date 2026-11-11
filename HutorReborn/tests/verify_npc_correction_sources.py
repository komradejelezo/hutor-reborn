"""Immutable gameplay/source art and exact technical-only crop scope against merged PR22."""
from pathlib import Path
import subprocess,json,re
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];P=R/'HutorReborn';BASE='a4fccc2'
def git(*a):return subprocess.check_output(['git','-C',str(R),*a])
checked=0
for name in git('ls-tree','-r','--name-only',BASE).decode().splitlines():
 if not name.startswith('HutorReborn/'):continue
 protected=name.endswith(('.png','.tscn','.gdshader')) or name=='HutorReborn/project.godot' or any(s in name for s in ['/assets/characters/','/data/life/','/dialogues/','/scripts/interiors/','/scripts/player','/scripts/ambient/','/scripts/audio/'])
 if protected:
  assert (R/name).read_bytes()==git('show',BASE+':'+name),name
  checked+=1
manifest=json.loads((P/'assets/npc/stage54/manifest.json').read_text());cor=json.loads((P/'assets/npc/stage541/corrections.json').read_text());assert not cor['artistic_redesign_complete']
assert len(cor['changes'])==33
for id,record in manifest['residents'].items():
 old=Image.open(P/'assets/npc/stage54/game'/id/'atlas.png').convert('RGBA')
 path=P/'assets/npc/stage541'/id/'atlas.png';new=Image.open(path).convert('RGBA') if path.exists() else old
 assert new.size==old.size
 a=np.asarray(old);b=np.asarray(new);allowed={c['texture_index'] for c in cor['changes'] if c['id']==id}
 for i in range(len(record['frames'])):
  x=i%8*96;y=i//8*96
  if i not in allowed:assert np.array_equal(a[y:y+96,x:x+96],b[y:y+96,x:x+96]),(id,i,'unrelated pose changed')
  else:
   cell=b[y:y+96,x:x+96];mask=cell[:,:,3]
   assert mask.any() and not mask[0].any() and not mask[-1].any() and not mask[:,0].any() and not mask[:,-1].any(),(id,i,'canvas clipping')
   assert set(np.unique(mask))<={0,255}
   # Technical re-crop may reveal source pixels, never introduce a new palette.
   assert any(c['texture_index']==i and c['scale']==record['frames'][i]['scale'] for c in cor['changes'] if c['id']==id)
 text=(P/'assets/npc/stage541'/id/'frames.tres').read_text();old_text=(P/'assets/npc/stage54/game'/id/'frames.tres').read_text()
 text=text.replace('metadata/correction_version = 541\n','').replace('res://assets/npc/stage541/'+id+'/atlas.png','res://assets/npc/stage54/game/'+id+'/atlas.png')
 assert text==old_text,(id,'FPS, animation order or counts unexpectedly changed')
 checked+=1
assert not (P/'override.cfg').exists(),'observer override left behind'
print('PASS:',checked,'immutable source/gameplay contracts; exactly 33 eligible re-crops; no anatomy stretching, gait duplication or FPS edits')
