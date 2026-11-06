"""Arrange unretouched Stage 3.3 captures, preserving native screenshot pixels."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image,ImageDraw,ImageFont

P=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
out=P.parent/'deliverables'
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),16)
small=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),13)

def compose(filename,title,views):
    image=Image.new('RGB',(1296,52+len(views)*398),(21,23,22))
    text=ImageDraw.Draw(image)
    text.text((12,6),title,font=font,fill=(224,210,182))
    text.text((12,30),'Одинаковые ракурсы, атмосфера включена, вырезки 1:1; пиксели снимков не обработаны.',font=small,fill=(164,164,155))
    for row,(name,label,box) in enumerate(views):
        top=52+row*398
        for col,prefix in enumerate(['before','after']):
            x=col*656
            text.text((x+8,top+4),('ДО — ' if col==0 else 'ПОСЛЕ — ')+label,font=font,fill=(224,210,182))
            crop=Image.open(source/(prefix+'-'+name+'.png')).crop(box)
            assert crop.size==(640,360)
            image.paste(crop,(x,top+30))
    image.save(out/filename)

compose('Stage33-lighting-before-after.png','Кривая Сосна — мягкий вечерний свет',[
    ('plaza','центральная площадь',(160,90,800,450)),
    ('elder','окна и фонарь',(120,20,760,380)),
    ('herbalist','двор знахарки',(160,60,800,420)),
    ('gate','вход в хутор',(160,100,800,460)),
])
compose('Stage33-mist-before-after.png','Кривая Сосна — дымка и читаемость Ганса',[
    ('north','северная дорога',(160,20,800,380)),
    ('pine','у Кривой сосны',(160,150,800,510)),
])
for name in ['gameplay','overview']:
    shutil.copy2(source/('after-'+name+'.png'),out/('Stage33-'+name+'.png'))
if all((source/('performance-'+v+s+'.json')).exists() for v in ['before','after'] for s in ['', '-repeat']):
    bench={}
    for version in ['before','after']:
        rows=[json.loads((source/('performance-'+version+suffix+'.json')).read_text()) for suffix in ['', '-repeat']]
        bench[version]={'scene_tree_nodes':rows[0]['nodes'],'collision_shapes':rows[0]['solid_shapes'],'wind_nodes':rows[0]['wind_nodes'],'individual_runs':rows,'views':[]}
        for i in range(4):
            data={'center':rows[0]['views'][i]['center']}
            for key in ['process_ms','physics_ms','draw_calls','drawn_objects']:
                data[key]=sum(r['views'][i][key] for r in rows)/len(rows)
            bench[version]['views'].append(data)
    (P/'docs/stage33-performance.json').write_text(json.dumps({'renderer':'Godot 4.6.3 / Mesa llvmpipe','runs_per_version':2,'order':'after, before; before, after','warmup_frames':45,'samples_per_view_per_run':90,'results':bench},indent=2)+'\n')
print('Prepared Stage 3.3 native overview/gameplay and six before/after pairs')
