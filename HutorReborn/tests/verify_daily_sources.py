"""Frozen 4.5 foundation, schedule schema and original nearest-sampled action pixels."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

P=Path(__file__).resolve().parents[1]
audit=json.loads((P/'docs/stage46-preserved-files.json').read_text(encoding='utf-8'))
checks=0

def check(condition,message):
    global checks
    assert condition,message
    checks+=1

for name,sha in audit['files'].items():
    check(hashlib.sha256((P/name).read_bytes()).hexdigest()==sha,'Protected 4.5 file changed: '+name)
registry=json.loads((P/'data/life/registry.json').read_text())
check(registry['real_day_seconds']==1800,'Default 30-minute day')
profiles=[json.loads((P/path.removeprefix('res://')).read_text()) for path in registry['residents']]
ids={r['id'] for r in profiles}
check(len(ids)==len(profiles)==9,'Exactly nine existing unique IDs')
for r in profiles:
    check((P/'assets/npc/stage43'/r['id']/'definition.tres').is_file(),'Existing resident identity')
    starts=[b['start'] for b in r['blocks']]
    check(starts==sorted(set(starts)) and starts[0]==0 and starts[-1]<1440,'Total ordered daily coverage: '+r['id'])
    for block in r['blocks']:
        check(bool(block['activities']),'Nonempty activity loop')
        for act in block['activities']:
            check(act['minutes']>0 and act['id'],'Positive activity duration')
            check(act['point'] is None if block['scene']=='logging' else isinstance(act['point'],(str,list)),'Virtual or real activity point')
manifest=json.loads((P/'assets/npc/stage46/manifest.json').read_text())
base=json.loads((P/'assets/npc/stage43/sprite_manifest.json').read_text())['residents']
count=0
for npc,data in manifest.items():
    atlas=Image.open(P/'assets/npc/stage46'/(npc+'.png')).convert('RGBA')
    # Compare to the existing action-cell scale, because inn walk sheets use another resolution.
    ratio=next(f['scale'] for f in base[npc]['frames'] if f['box'][2]-f['box'][0]==793)
    for index,f in enumerate(data['frames']):
        src=P/f['source']
        check(hashlib.sha256(src.read_bytes()).hexdigest()==f['sha256'],'Original action source hash')
        check(f['scale']==ratio,'Approved actor body scale')
        crop=Image.open(src).convert('RGBA').crop(tuple(f['box']))
        nearest=crop.resize(tuple(f['resized']),Image.Resampling.NEAREST)
        expected=Image.new('RGBA',(96,96));expected.paste(nearest,tuple(f['offset']))
        actual=np.array(atlas.crop((index%8*96,index//8*96,index%8*96+96,index//8*96+96)))
        e=np.array(expected);visible=actual[:,:,3]>0
        check(visible.sum()>30,'Visible action frame')
        check(np.array_equal(actual[visible],e[visible]),'Unpainted original pixels + original alpha, sampled Nearest')
        check(actual[:2,:,3].sum()==0 and actual[-2:,:,3].sum()==0 and actual[:,:2,3].sum()==0 and actual[:,-2:,3].sum()==0,'No clipped body at canvas edges')
        check(f['resized'][0]/793<.08 and f['resized'][1]/1285<.08,'Action sheet never uses low-resolution walk-sheet ratio')
        count+=1
check(count==36,'36 genuine additional archived frames')
print(f'PASS: {checks} daily-source checks; {len(audit["files"])} frozen files byte-identical; {count} original action frames')
