"""Arrange Stage 3.2 native screenshots; never resize/repaint the scene crops."""
from pathlib import Path
import json
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

P=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
out=P.parent/'deliverables'
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),16)
small=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),13)

def compose(filename,title,views):
    image=Image.new('RGB',(1296,52+len(views)*398),(21,23,22))
    text=ImageDraw.Draw(image)
    text.text((12,6),title,font=font,fill=(224,210,182))
    text.text((12,30),'До / после: одинаковые ракурсы, нативные пиксели 1:1; без тумана для проверки деталей.',font=small,fill=(164,164,155))
    for row,(name,label,box) in enumerate(views):
        top=52+row*398
        for col,prefix in enumerate(['before','after']):
            x=col*656
            text.text((x+8,top+4),('ДО — ' if col==0 else 'ПОСЛЕ — ')+label,font=font,fill=(224,210,182))
            crop=Image.open(source/(prefix+'-'+name+'.png')).crop(box)
            assert crop.size==(640,360)
            image.paste(crop,(x,top+30))
    image.save(out/filename)

compose('Stage32-courtyards-before-after.png','Кривая Сосна — пять разных хозяйственных дворов',[
    ('elder','двор старосты',(160,60,800,420)),
    ('miller','двор мельника',(160,60,800,420)),
    ('common','общий дом',(160,0,800,360)),
    ('hunter','двор охотника',(160,80,800,440)),
    ('herbalist','двор знахарки',(220,70,860,430)),
])
compose('Stage32-forest-before-after.png','Кривая Сосна — лес и главный ориентир',[
    ('north','северная граница леса',(160,70,800,430)),
    ('forest','восточная лесная тропа',(160,90,800,450)),
])
pine=Image.new('RGB',(1296,554),(21,23,22))
draw=ImageDraw.Draw(pine)
draw.text((12,6),'Кривая сосна — оригинальный силуэт сохранён, окружение освобождено',font=font,fill=(224,210,182))
for col,prefix in enumerate(['before','after']):
    draw.text((col*656+8,32),'ДО' if col==0 else 'ПОСЛЕ',font=font,fill=(224,210,182))
    crop=Image.open(source/(prefix+'-overview.png')).crop((240,450,880,950))
    pine.paste(crop,(col*656,54))
pine.save(out/'Stage32-pine-before-after.png')
for name in ['gameplay','overview']:
    shutil.copy2(source/('after-'+name+'.png'),out/('Stage32-'+name+'.png'))
bench={}
for version in ['before','after']:
    rows=[json.loads((source/('performance-'+version+suffix+'.json')).read_text()) for suffix in ['', '-repeat']]
    bench[version]={'wind_material_nodes':rows[0]['wind_nodes'],'scene_tree_nodes':rows[0]['nodes'],'collision_shapes':rows[0]['solid_shapes'],'views':[]}
    for i in range(4):
        data={'center':rows[0]['views'][i]['center']}
        for key in ['process_ms','physics_ms','draw_calls','drawn_objects']:
            data[key]=sum(r['views'][i][key] for r in rows)/len(rows)
        bench[version]['views'].append(data)
(P/'docs/stage32-performance.json').write_text(json.dumps({'renderer':'Godot 4.6.3 / Mesa llvmpipe','warmup_frames_per_view':45,'samples_per_view_per_run':90,'runs_per_version':2,'order':'before, after; after, before','results':bench},indent=2)+'\n')
print('Saved Stage 3.2 overview, gameplay and eight native before/after comparisons; performance summary')
