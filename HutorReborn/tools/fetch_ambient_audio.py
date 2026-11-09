"""Authoring only: fetch pinned, credited media; never runs with the game."""
from pathlib import Path
import urllib.request,json,hashlib
root=Path(__file__).resolve().parents[1]/'assets/audio/ambient'
root.mkdir(parents=True,exist_ok=True)
(root/'licenses').mkdir(exist_ok=True)
a='61a3b9507d974084e6badb88a0826bd89a6d5b8b';m='9e895af6e9feb98332fa1a778001442f5669bc20'
files=[('forest_day','0ad/0ad',a,'binaries/data/mods/public/audio/ambient/dayscape/day_temperate_gen_01.ogg','Wildfire Games','CC-BY-SA-3.0'),('forest_bird','0ad/0ad',a,'binaries/data/mods/public/audio/ambient/dayscape/day_temperate_11.ogg','Wildfire Games','CC-BY-SA-3.0'),('wind','0ad/0ad',a,'binaries/data/mods/public/audio/ambient/weather/wind_11.ogg','Wildfire Games','CC-BY-SA-3.0'),('leaves_1','0ad/0ad',a,'binaries/data/mods/public/audio/ambient/weather/windleaves_10.ogg','Wildfire Games','CC-BY-SA-3.0'),('leaves_2','0ad/0ad',a,'binaries/data/mods/public/audio/ambient/weather/windleaves_11.ogg','Wildfire Games','CC-BY-SA-3.0'),('axe_1','0ad/0ad',a,'binaries/data/mods/public/audio/resource/lumbering/lumber_tree_01.ogg','Wildfire Games','CC-BY-SA-3.0'),('axe_2','0ad/0ad',a,'binaries/data/mods/public/audio/resource/lumbering/lumber_tree_02.ogg','Wildfire Games','CC-BY-SA-3.0'),('wood_1','0ad/0ad',a,'binaries/data/mods/public/audio/resource/construction/con_wood_01.ogg','Wildfire Games','CC-BY-SA-3.0'),('wood_2','0ad/0ad',a,'binaries/data/mods/public/audio/resource/construction/con_wood_02.ogg','Wildfire Games','CC-BY-SA-3.0'),('fire','luanti-org/minetest_game',m,'mods/fire/sounds/fire_small.ogg','dobroide','CC-BY-3.0'),('wood_creak','luanti-org/minetest_game',m,'mods/default/sounds/default_chest_open.ogg','sofar; Sevin7; Percy Duke; kingsamas; bulbastre; Yoyodaman234','CC-BY-SA-3.0 upstream media; CC-BY-3.0 / CC0 components')]
records=[]
for name,repo,sha,path,author,license in files:
 url=f'https://raw.githubusercontent.com/{repo}/{sha}/{path}'
 data=urllib.request.urlopen(url,timeout=30).read()
 assert data[:4]==b'OggS',name
 (root/(name+'.ogg')).write_bytes(data)
 records.append(dict(id=name,file=name+'.ogg',source=url,repository=repo,revision=sha,author=author,license=license,sha256=hashlib.sha256(data).hexdigest(),modified=False))
 print(name,len(data),flush=True)
for name,repo,sha,path in [('0ad-audio.txt','0ad/0ad',a,'binaries/data/mods/public/audio/LICENSE.txt'),('minetest-fire-readme.md','luanti-org/minetest_game',m,'mods/fire/README.md'),('minetest-fire-license.txt','luanti-org/minetest_game',m,'mods/fire/license.txt'),('minetest-default-readme.md','luanti-org/minetest_game',m,'mods/default/README.md'),('minetest-default-license.txt','luanti-org/minetest_game',m,'mods/default/license.txt')]:
 (root/'licenses'/name).write_bytes(urllib.request.urlopen(f'https://raw.githubusercontent.com/{repo}/{sha}/{path}',timeout=30).read())
(root/'sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
