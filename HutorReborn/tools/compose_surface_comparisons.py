"""Arrange native rendered crops, without resampling or repainting their pixels.
Usage: python3 tools/compose_surface_comparisons.py /path/to/review-output
"""
from pathlib import Path
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

P=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
out=P.parent/'deliverables'
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),16)
small=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),13)

def compose(filename,title,views):
    canvas=Image.new('RGB',(1296,52+len(views)*398),(21,23,22))
    text=ImageDraw.Draw(canvas)
    text.text((12,6),title,font=font,fill=(224,210,182))
    text.text((12,30),'Одинаковые ракурсы, исходный масштаб 1:1; диагностические виды без тумана.',font=small,fill=(164,164,155))
    for row,(name,label,box) in enumerate(views):
        top=52+row*398
        for col,prefix in enumerate(['before','after']):
            x=col*656
            text.text((x+8,top+4),('ДО — ' if col==0 else 'ПОСЛЕ — ')+label,font=font,fill=(224,210,182))
            image=Image.open(source/(prefix+'-'+name+'.png')).crop(box)
            assert image.size==(640,360)
            canvas.paste(image,(x,top+30))
    canvas.save(out/filename)

compose('Stage31-houses-before-after.png','Кривая Сосна — поверхность у пяти домов',[
    ('elder','дом старшего',(160,60,800,420)),
    ('miller','дом мельника',(160,60,800,420)),
    ('common','общий дом и площадь',(160,0,800,360)),
    ('carpenter','дом плотника',(160,80,800,440)),
    ('herbalist','дом знахарки и огород',(220,70,860,430)),
])
compose('Stage31-paths-before-after.png','Кривая Сосна — дороги и лесная земля',[
    ('forest','лесная тропа и развилка',(120,150,760,510)),
    ('junction','соединение дорог у общего двора',(160,90,800,450)),
])
for name in ['gameplay','overview']:
    shutil.copy2(source/('after-'+name+'.png'),out/('Stage31-'+name+'.png'))
print('Prepared four Stage 3.1 screenshots/comparison boards; native pixels retained')
