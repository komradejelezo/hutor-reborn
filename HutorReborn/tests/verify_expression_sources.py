"""Frozen schedules/world/time/UI/Hans and exact source sampling for Stage 4.7."""
from pathlib import Path
import hashlib,json
from PIL import Image
import numpy as np
P=Path(__file__).resolve().parents[1]
checks=0
def check(ok,message):
 global checks
 assert ok,message
 checks+=1
baseline=json.loads((P/'docs/stage47-preserved-files.json').read_text())
for name,sha in baseline['files'].items():check(hashlib.sha256((P/name).read_bytes()).hexdigest()==sha,'Protected file changed: '+name)
life=(P/'scripts/life/village_life.gd').read_text()
a=life.index('func _frames_for(');b=life.index('\nfunc _definition(',a)
check(hashlib.sha256((life[:a]+life[b:]).encode()).hexdigest()==baseline['life_except_visual_frames_sha256'],'Residency/schedule owner changed only its visual-frame resolver')
for id,original in baseline['original_dialogues'].items():
 current=json.loads((P/'dialogues/residents'/(id+'.json')).read_text())
 for line in current['nodes']:line.pop('portraits',None)
 check(current==original,'Dialogue graph/text/emotions unchanged: '+id)
profiles=json.loads((P/'data/visuals/residents.json').read_text())
records=json.loads((P/'assets/npc/stage47/portraits/manifest.json').read_text())
check(len(records)==36,'Exactly nine by four portraits')
seen=set()
for r in records:
 source=P/r['source'];target=P/r['path']
 check(hashlib.sha256(source.read_bytes()).hexdigest()==r['source_sha256'],'Exact generated atlas preserved')
 expected=Image.open(source).convert('RGBA').crop(r['box']).resize(tuple(r['size']),Image.Resampling.NEAREST)
 actual=Image.open(target).convert('RGBA')
 check(actual.size==(128,192) and np.array_equal(np.array(actual),np.array(expected)),'Uniform unpainted portrait crop: '+r['id']+'/'+r['emotion'])
 check(r['box'][2]-r['box'][0]==240 and r['box'][3]-r['box'][1]==360,'Exact 2:3 source crop')
 key=hashlib.sha256(actual.tobytes()).hexdigest();check(key not in seen,'Distinct actual face/expression pixels');seen.add(key)
 check(profiles[r['id']]['portraits'][r['emotion']]=='res://'+r['path'],'Correct identity slot')
meta=json.loads((P/'assets/npc/stage47/animation_manifest.json').read_text())
atlas=Image.open(P/'assets/npc/stage47/woodcutter_saw.png').convert('RGBA')
for i,r in enumerate(meta['frames']):
 src=P/r['source'];check(hashlib.sha256(src.read_bytes()).hexdigest()==meta['sha256'],'Original saw source intact')
 frame=Image.open(src).convert('RGBA').crop(r['box']).resize(tuple(r['size']),Image.Resampling.NEAREST)
 expected=Image.new('RGBA',(96,96));expected.paste(frame,tuple(r['offset']))
 a=np.array(atlas.crop((i*96,0,(i+1)*96,96)));e=np.array(expected);visible=a[:,:,3]>0
 check(np.array_equal(a[visible],e[visible]),'Actual source colours/alpha in saw frame')
 check(a[:2,:,3].sum()==0 and a[-2:,:,3].sum()==0,'Body not clipped at anchor')
print(f'PASS: {checks} expression-source checks; {len(baseline["files"])} old files byte-identical; 36 individual portraits, six original saw frames')
