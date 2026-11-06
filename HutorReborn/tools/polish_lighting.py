"""Stage 3.3 authoring: existing lights/fog and focused house occlusion only.
Never regenerates terrain, objects, art, collision shapes or camera configuration.
"""
from pathlib import Path
import json
import re

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/environment/krivaya_sosna/stage33'
OUT.mkdir(exist_ok=True)
SCENE=P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn'
text=SCENE.read_text()
cookie='''[gd_resource type="GradientTexture2D" format=3]

[sub_resource type="Gradient" id="Falloff"]
interpolation_mode = 2
offsets = PackedFloat32Array(0, 0.12, 0.33, 0.55, 0.78, 1)
colors = PackedColorArray(1,1,1,1, 1,1,1,0.9, 1,1,1,0.62, 1,1,1,0.32, 1,1,1,0.10, 1,1,1,0)

[resource]
gradient = SubResource("Falloff")
width = 512
height = 512
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 1)
'''
(OUT/'soft_light.tres').write_text(cookie)
(OUT/'mist_noise.tres').write_text('''[gd_resource type="NoiseTexture2D" format=3]

[sub_resource type="FastNoiseLite" id="CloudNoise"]
seed = 3306046
frequency = 0.035
fractal_octaves = 2

[resource]
width = 256
height = 256
generate_mipmaps = false
seamless_enabled = true
noise = SubResource("CloudNoise")
''')
text=text.replace('res://assets/environment/light.png','res://assets/environment/krivaya_sosna/stage33/soft_light.tres')
text=text.replace('res://shaders/atmosphere.gdshader','res://shaders/evening_mist.gdshader')
text=re.sub(r'^shader_parameter/fog_strength = [^\n]+','shader_parameter/fog_strength = 0.032',text,flags=re.M)
if 'id="s33_noise"' not in text:
    i=text.index('[sub_resource')
    text=text[:i]+'[ext_resource type="Texture2D" path="res://assets/environment/krivaya_sosna/stage33/mist_noise.tres" id="s33_noise"]\n\n'+text[i:]
if 'shader_parameter/mist_noise' not in text:
    text=text.replace('shader_parameter/fog_strength = 0.032','shader_parameter/fog_strength = 0.032\nshader_parameter/mist_noise = ExtResource("s33_noise")')

def set_value(body,key,value):
    pattern=rf'^{re.escape(key)} = [^\n]+$'
    if re.search(pattern,body,re.M):return re.sub(pattern,key+' = '+value,body,flags=re.M)
    return body.rstrip()+'\n'+key+' = '+value+'\n\n'

lights=[]
def edit_node(match):
    header,body=match[1],match[2]
    if 'type="PointLight2D"' in header:
        parent=re.search(r'parent="([^"]+)"',header)[1]
        name=re.search(r'name="([^"]+)"',header)[1]
        lantern='HangingLantern' in parent
        shadow=parent.endswith('HangingLantern189')
        is_gate='GatePost' in parent
        is_common=parent.endswith('/CommonHouse')
        if lantern:energy,scale=.56,1.10
        elif is_gate:energy,scale=.48,.90
        elif is_common and name=='WarmLight7':energy,scale=.40,1.15
        elif is_common:energy,scale=(.48,.85) if name=='WarmLight5' else (.36,.80)
        elif name=='WarmLight4':energy,scale=.42,.75
        else:energy,scale=.30,1.0
        scale*=.5  # 512px native falloff retains the approved world-space light radius.
        for key,value in {'texture_filter':'1','color':'Color(0.96, 0.80, 0.63, 1)','energy':str(energy),'base_energy':str(energy),'texture_scale':str(scale),'flicker':'0.012' if lantern or is_gate else '0.0','update_interval':'0.12','shadow_enabled':'true' if shadow else 'false'}.items():
            body=set_value(body,key,value)
        if shadow:
            body=set_value(body,'shadow_filter','1')
            body=set_value(body,'shadow_filter_smooth','1.4')
        lights.append({'path':parent+'/'+name,'energy':energy,'texture_scale':scale,'shadow':shadow})
    elif 'name="Evening" type="CanvasModulate"' in header:
        body=set_value(body,'color','Color(0.89, 0.91, 0.94, 1)')
    elif 'name="Atmosphere" type="Node2D"' in header:
        body=set_value(body,'world_space_fog','true')
    return header+'\n'+body
text=re.sub(r'^(\[node[^\n]+\])\n(.*?)(?=^\[|\Z)',edit_node,text,flags=re.M|re.S)
assert len(lights)==17
# Re-running replaces just the authored visual occluders.
text=re.sub(r'^\[sub_resource type="OccluderPolygon2D" id="s33_[^\n]+\]\n.*?(?=^\[|\Z)','',text,flags=re.M|re.S)
text=re.sub(r'^\[node name="HouseLightOccluder"[^\n]+\]\n.*?(?=^\[|\Z)','',text,flags=re.M|re.S)
polygons=[]
occluders=[]
for name,key in [('CommonHouse','common_house')]:
    data=(P/'scenes/objects/krivaya_sosna'/(key+'.tscn')).read_text()
    size=re.search(r'size = Vector2\(([^,]+), ([^)]+)\)',data)
    position=re.search(r'\[node name="Footprint"[^\n]+\]\nposition = Vector2\(([^,]+), ([^)]+)\)',data)
    w,h=map(float,size.groups());x,y=map(float,position.groups())
    points=[x-w/2,y-h/2,x+w/2,y-h/2,x+w/2,y+h/2,x-w/2,y+h/2]
    polygons.append(f'[sub_resource type="OccluderPolygon2D" id="s33_{name}"]\npolygon = PackedVector2Array('+', '.join(map(str,points))+')\n\n')
    occluders.append(f'[node name="HouseLightOccluder" type="LightOccluder2D" parent="Actors/Structures/{name}"]\noccluder = SubResource("s33_{name}")\nsdf_collision = false\n\n')
offset=text.index('[node name="KrivayaSosna"')
text=text[:offset].rstrip()+'\n\n'+''.join(polygons)+text[offset:]
text=text.rstrip()+'\n\n'+''.join(occluders)
SCENE.write_text(text.rstrip()+'\n')
(OUT/'lighting_profile.json').write_text(json.dumps({'lights':lights,'shadow_lights':1,'house_occluders':1,'particles':55,'ambient':[.89,.91,.94],'world_space_fog':True},ensure_ascii=False,indent=2)+'\n')
print('Polished 17 existing lights; 1 focused common-house occluder/shadow lantern; one cached-texture fog pass; no layout/collision/camera edits')
