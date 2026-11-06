"""Validate all approved Stage 3.2 geometry/art against a real scene audit.
Usage: python3 verify_lighting_invariants.py /path/to/after-audit.json
"""
from pathlib import Path
import hashlib
import json
import re
import sys

P=Path(__file__).resolve().parents[1]
baseline=json.loads((P/'docs/stage33-preserved-files.json').read_text())
for name,digest in baseline['files'].items():
    assert hashlib.sha256((P/name).read_bytes()).hexdigest()==digest,name
scene=(P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn').read_text()
assert [hashlib.sha256(t.encode()).hexdigest() for t in re.findall(r'tile_map_data = [^\n]+',scene)]==baseline['tile_data']
print(f"PASS: {len(baseline['files'])} approved files unchanged, including all art, player, camera, terrain and environment resources")
state=json.loads(Path(sys.argv[1]).read_text())['scene_state']
for key,digest in baseline['nodes'].items():
    assert hashlib.sha256(json.dumps(state[key],sort_keys=True,separators=(',',':')).encode()).hexdigest()==digest,key
print(f"PASS: {len(baseline['nodes'])} protected nodes exactly preserved; all positions, physics and scales unchanged")
light_fields={'color','energy','base_energy','texture_scale','flicker','texture','texture_filter','shadow_enabled','shadow_filter','shadow_filter_smooth','update_interval','flicker_speed'}
for key,previous in baseline['visual_nodes'].items():
    permitted=light_fields if previous['class']=='PointLight2D' else ({'color'} if key=='Lighting/Evening' else {'world_space_fog','process_priority'})
    current=state[key]
    for field in set(previous)|set(current):
        if previous.get(field)!=current.get(field):assert field in permitted,(key,field)
extra=set(state)-set(baseline['nodes'])-set(baseline['visual_nodes'])
expected={'Actors/Structures/CommonHouse/HouseLightOccluder'}
assert extra==expected,extra
for key in extra:
    assert state[key]['class']=='LightOccluder2D'
    assert not state[key]['sdf_collision']
    assert state[key]['position']=='(0.0, 0.0)'
assert sum(v['class']=='PointLight2D' for v in state.values())==17
for kind in ['CollisionShape2D','StaticBody2D','CharacterBody2D','Area2D','CPUParticles2D']:
    assert sum(v['class']==kind for v in state.values())==baseline['class_counts'].get(kind,0),kind
print('PASS: visual edits limited to 17 existing lights, one ambient colour, atmosphere configuration and one native nonphysical occluder')
assert 'res://shaders/atmosphere.gdshader' not in scene
assert (P/'shaders/atmosphere.gdshader').exists()
assert (P/'assets/environment/light.png').exists()
print('PASS: legacy fog shader and original light PNG retained; current map opts into the new technical resources')
