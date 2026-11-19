#!/usr/bin/env python3
"""Exercise the read-only auditor on deliberately faulty and natural fixtures."""
import sys
from pathlib import Path
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from audit_combat_graphics import inspect_image,runtime_sequences
empty=Image.new('RGBA',(32,32))
assert inspect_image(empty)['empty']
body=empty.copy();d=ImageDraw.Draw(body);d.rectangle((7,4,24,28),fill=(30,20,10,255))
a=inspect_image(body);assert a['opaque']==450 and a['edge_pixels']==0 and not a['empty']
d.rectangle((12,10,15,16),fill=(0,0,0,0))
a=inspect_image(body);assert a['holes']==1 and a['hole_pixels']==28
# A gap is a review candidate; the function must not fill natural openings.
assert body.getpixel((13,12))[3]==0
clipped=empty.copy();ImageDraw.Draw(clipped).rectangle((0,3,15,24),fill=(1,1,1,255))
assert inspect_image(clipped)['edge_pixels']==22
semi=Image.new('RGBA',(32,32),(5,5,5,100));assert inspect_image(semi)['opaque']==0
seq=runtime_sequences();assert len(seq)==7 and len(seq['spirit']['default'])==1
assert set(seq['hans'])=={'idle','attack','hit','dodge','victory','death','use_invoke'}
assert 'idle_down' in seq['woodcutter'] and 'idle_down' in seq['herbalist']
import tempfile
import audit_combat_graphics as audit
original_root=audit.P;original_sequences=audit.runtime_sequences
with tempfile.TemporaryDirectory() as temp:
    audit.P=Path(temp)
    audit.runtime_sequences=lambda:{'fixture':{'missing':[{'path':'absent.png'}]}}
    assert audit.run(Path(temp)/'report')==1
    import json
    findings=json.loads((Path(temp)/'report/graphics_audit.json').read_text())['findings']
    assert findings[0]['type']=='missing' and findings[0]['severity']=='error'
    Image.new('RGB',(32,32),(30,20,10)).save(Path(temp)/'rgb.png')
    Image.new('RGBA',(32,32),(30,20,10,255)).save(Path(temp)/'rgba.png')
    (Path(temp)/'broken.png').write_bytes(b'not a PNG')
    audit.runtime_sequences=lambda:{'fixture':{'rgb':[{'path':'rgb.png'}],'crop':[{'path':'rgba.png','crop':[0,0,40,32]}],'corrupt':[{'path':'broken.png'}],'size':[{'path':'rgba.png','expected_size':[33,32]}]}}
    assert audit.run(Path(temp)/'report2')==4
    findings=json.loads((Path(temp)/'report2/graphics_audit.json').read_text())['findings']
    assert {x['type'] for x in findings if x['severity']=='error'}=={'missing_alpha','invalid_crop','invalid_image','size_mismatch'}
audit.P=original_root;audit.runtime_sequences=original_sequences
print('RESULT: 10 graphics-auditor fixture groups passed')
