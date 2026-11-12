"""Stage 5.4.3: approved animation/artwork and gameplay must remain byte-identical."""
from pathlib import Path
import hashlib,json,subprocess

REPO=Path(__file__).resolve().parents[2]
BASE='c90b6d3'

def original(path):
    return subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=REPO)

paths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'HutorReborn'],cwd=REPO,text=True).splitlines()
protected=[]
for path in paths:
    # Every old image/resource, every actor except its presentation scene,
    # and all schedules/dialogue data/navigation remain fixed.
    if (path.endswith(('.png','.tres','.json','.gdshader'))
        or path.startswith(('HutorReborn/assets/characters/','HutorReborn/scripts/player/','HutorReborn/scripts/life/','HutorReborn/scripts/transitions/'))
        or path.endswith('.tscn')) and path!='HutorReborn/scenes/npc/residents/woodcutter.tscn':
        data=(REPO/path).read_bytes()
        assert data==original(path),f'Protected baseline changed: {path}'
        protected.append(path)
frames='HutorReborn/assets/npc/woodcutter542/game/frames.tres'
atlas='HutorReborn/assets/npc/woodcutter542/game/atlas.png'
print(f'PASS: {len(protected)} old art/animation/scene/data/gameplay files unchanged from {BASE}')
for path in [frames,atlas]:print('SHA256',path,hashlib.sha256((REPO/path).read_bytes()).hexdigest())
manifest=json.loads((REPO/'HutorReborn/assets/npc/woodcutter542/manifest.json').read_text())
assert all(len(manifest['clips']['walk_'+d])==6 for d in ['down','up','left','right'])
assert b'UV =' not in (REPO/'HutorReborn/shaders/woodcutter_palette.gdshader').read_bytes()
assert not subprocess.check_output(['git','diff','--diff-filter=D','--name-only',BASE],cwd=REPO)
print('PASS: four unchanged six-pose walk cycles; no old file deleted')
