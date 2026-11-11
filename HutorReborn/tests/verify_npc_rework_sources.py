"""Stage54 source provenance, immutable gameplay and atlas contracts.
Run from any directory in a Git checkout; Pillow/numpy required.
"""
from pathlib import Path
import hashlib,json,re,subprocess
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'HutorReborn';BASE='457c1cf'
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args])
def old(path):return git('show',BASE+':'+path)
checked=0
for name in git('ls-tree','-r','--name-only',BASE).decode().splitlines():
 if not name.startswith('HutorReborn/'):continue
 if name.endswith(('.png','.tscn','.shader','.gdshader')) or any(x in name for x in ['/data/life/','/assets/characters/','/scripts/player/','/scripts/interiors/','/scripts/audio/','/scripts/ambient/']) or name=='HutorReborn/project.godot':
  assert (ROOT/name).read_bytes()==old(name),name+' changed protected gameplay/source'
  checked+=1
for path in (P/'dialogues/residents').glob('*.json'):
 previous=json.loads(old(str(path.relative_to(ROOT))));current=json.loads(path.read_text())
 def normalize(value):
  if isinstance(value,dict):return {k:normalize(v) for k,v in value.items()}
  if isinstance(value,list):return [normalize(v) for v in value]
  if isinstance(value,str):return re.sub(r'res://assets/npc/stage54/game/([^/]+)/portraits/',r'res://assets/npc/stage47/portraits/\1/',value)
  return value
 assert normalize(current)==previous,'dialogue graph/text changed '+path.name
 checked+=1
m=json.loads((P/'assets/npc/stage54/manifest.json').read_text());assert len(m['residents'])==9
for id,r in m['residents'].items():
 source=P/r['reference'];assert hashlib.sha256(source.read_bytes()).hexdigest()==r['sha256']
 im=Image.open(P/'assets/npc/stage54/game'/id/'atlas.png');assert im.mode=='RGBA'
 a=np.asarray(im);assert set(np.unique(a[:,:,3]))=={0,255}
 for f in r['frames']:
  index=r['clips'][f['clip']][f['index']];x=index%8*96;y=index//8*96;c=a[y:y+96,x:x+96,3]
  assert c.any() and not c[0].any() and not c[-1].any() and not c[:,0].any() and not c[:,-1].any(),(id,f['clip'],f['index'],'canvas clipping')
 for direction in ['down','up','left','right']:
  indices=r['clips']['walk_'+direction];assert len(indices)==8
  hashes={hashlib.sha256(a[i//8*96:i//8*96+96,i%8*96:i%8*96+96].tobytes()).hexdigest() for i in indices}
  assert len(hashes)>=6,(id,direction,'duplicate drawings')
  floors=[int(np.nonzero(a[i//8*96:i//8*96+96,i%8*96:i%8*96+96,3])[0].max()) for i in indices]
  assert max(floors)-min(floors)<=3,(id,direction,'unstable feet or leftover board border')
 for emotion in ['neutral','joy','displeased','anxious']:assert Image.open(P/'assets/npc/stage54/game'/id/'portraits'/(emotion+'.png')).size==(128,192)
 checked+=1
assert not (P/'override.cfg').exists(),'temporary observer override remains'
print('PASS:',checked,'protected source/provenance contracts; nine RGBA atlases; dialogue text/graphs unchanged')
