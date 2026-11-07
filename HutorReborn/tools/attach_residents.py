"""Attach only the population instance; preserve every approved map node byte."""
from pathlib import Path
P=Path(__file__).resolve().parents[1]
scene=P/'scenes/world/krivaya_sosna/krivaya_sosna.tscn'
text=scene.read_text(encoding='utf-8')
reference='[ext_resource type="PackedScene" path="res://scenes/npc/residents.tscn" id="stage43_residents"]\n'
node='[node name="Residents" parent="Actors" instance=ExtResource("stage43_residents")]\n\n'
if reference not in text:
 i=text.index('[sub_resource');text=text[:i]+reference+'\n'+text[i:]
if node not in text:
 i=text.index('[node name="MapBounds"');text=text[:i]+node+text[i:]
scene.write_text(text,encoding='utf-8',newline='\n')
print('Attached the population; original terrain/objects/lighting/camera untouched')
