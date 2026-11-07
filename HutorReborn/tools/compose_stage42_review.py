"""Arrange unretouched captures; retain the native full-map screenshot separately."""
from pathlib import Path
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

P=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]);out=P.parent/'deliverables'
font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),16)
small=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),13)
for key in ['overview','inn','abandoned','gameplay']:
 shutil.copy2(source/('after-'+key+'.png'),out/('Stage42-'+key+'.png'))
pairs=[('miller','woodcutter','Двор семьи дровосека'),('common','storehouse','Общий склад'),('hunter','old-man','Дом старика'),('herbalist','herbalist','Дом травницы и её брата')]
im=Image.new('RGB',(1296,52+len(pairs)*398),(21,23,22));d=ImageDraw.Draw(im)
d.text((12,6),'Кривая Сосна — назначение домов и хозяйственных дворов',font=font,fill='#dfd0aa')
d.text((12,30),'Необработанные вырезки 1:1; те же камеры, атмосфера включена; фазы ветра и дыма различаются.',font=small,fill='#a5a591')
for row,(before,after,label) in enumerate(pairs):
 for col,name in enumerate(['before-'+before,'after-'+after]):
  x=col*656;y=52+row*398
  d.text((x+8,y+4),('ДО — ' if col==0 else 'ПОСЛЕ — ')+label,font=font,fill='#dfd0aa')
  im.paste(Image.open(source/(name+'.png')).crop((160,60,800,420)),(x,y+30))
im.save(out/'Stage42-yards-before-after.png')

overview=Image.open(source/'after-overview.png').convert('RGB')
scaled=overview.resize((1160,998),Image.Resampling.NEAREST)
sheet=Image.new('RGB',(1500,1070),(21,23,22));sheet.paste(scaled,(0,48));d=ImageDraw.Draw(sheet)
d.text((18,12),'Кривая Сосна — семь зданий. Номера нанесены поверх игрового снимка.',font=font,fill='#dfd0aa')
places=[('Дом старосты',(912,708)),('Семья дровосека',(1689,708)),('Общий склад',(1287,1162)),('Дом старика',(834,1587)),('Травница и её брат',(1739,1587)),('Большой трактир',(1688,2264)),('Заброшенный дом',(2700,1030))]
for number,(label,(x,y)) in enumerate(places,1):
 sx=round(x*1160/2976);sy=48+round((y-100)*998/2560)
 d.ellipse((sx-13,sy-13,sx+13,sy+13),fill='#191c15',outline='#c6a76c',width=2)
 d.text((sx-5,sy-10),str(number),font=font,fill='#ead9ae')
 d.text((1180,75+(number-1)*60),f'{number}. {label}',font=font,fill='#dfd0aa')
for i,line in enumerate(['Пять прежних домов','и Кривая сосна остаются','на своих местах.','','Трактир — у въездной дороги.','Пустой дом — восточный лес.','','2976 × 2560 px.','Без NPC и интерьеров.']):
 d.text((1180,550+i*23),line,font=small,fill='#aaa995')
d.text((18,1049),'Обзор уменьшен с Nearest. Полный снимок 1:1: Stage42-overview.png.',font=small,fill='#a5a591')
sheet.save(out/'Stage42-buildings-guide.png')
print('Saved native map/gameplay/new buildings, four before-after pairs and a labelled map guide')
