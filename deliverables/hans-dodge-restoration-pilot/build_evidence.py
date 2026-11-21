#!/usr/bin/env python3
"""Compose evidence from existing/frozen PNGs. No art creation or game edits."""
from pathlib import Path
import argparse,json,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
D=Path(__file__).resolve().parent;R=D.parents[1];P=R/'HutorReborn/assets/combat/forest_v2'
def font(n=18):return ImageFont.truetype(str(R/'HutorReborn/assets/fonts/DejaVuSans.ttf'),n)
def text(im,x,y,s,n=18):ImageDraw.Draw(im).text((x,y),s,font=font(n),fill=(20,20,20))
def matte(im,bg='white'):
    out=Image.new('RGBA',im.size,bg);out.alpha_composite(im.convert('RGBA'));return out.convert('RGB')
def read(n,after):
    if n in [6,7,8]:return Image.open(D/('restored' if after else 'before')/f'dodge_{n:02d}.png').convert('RGBA')
    return Image.open(P/f'prepared/Hans/Dodge/dodge_{n:02d}.png').convert('RGBA')
def main(captures):
    data=json.loads((D/'CURATION.json').read_text());(D/'manual').mkdir(exist_ok=True);(D/'godot').mkdir(exist_ok=True)
    for row in data['frames']:
        n=row['frame'];before=read(n,False);after=read(n,True)
        box=[155,145,225,225] if n==6 else [214,208,284,278]
        sheet=Image.new('RGB',(1750,680),(238,235,225))
        text(sheet,20,10,f'КАДР {n:02d} · ЧАСТИЧНАЯ ПРОБНАЯ РЕСТАВРАЦИЯ',26)
        text(sheet,20,51,'Новые текстурные фрагменты только внутри выбранных областей. Большие разрывы плаща не исправлены.',18)
        for x,title,im in [(20,'Текущая игра · 1:1',before),(400,'Пилот · 1:1',after)]:
            text(sheet,x,90,title);sheet.paste(matte(im),(x,125))
        for x,title,im in [(790,'До · увеличение 6×',before),(1260,'После · увеличение 6×',after)]:
            text(sheet,x,90,title);crop=matte(im.crop(box));sheet.paste(crop.resize((crop.width*6,crop.height*6),Image.Resampling.NEAREST),(x,125))
        text(sheet,20,625,f'Окно {box}; изменено {row["edited_pixels"]} пикс.; кадр 357×358, origin [172.5, 351] сохранён.',17)
        sheet.save(D/f'comparisons/FRAME_{n:02d}_BEFORE_AFTER.png')
        old_mask=np.array(Image.open(R/f'deliverables/hans-dodge-restoration-review/masks/dodge_{n:02d}.png').convert('RGBA'))
        a=np.array(after);confirmed=(old_mask[:,:,3]>0)&np.all(old_mask[:,:,:3]==[220,35,55],2)&(a[:,:,3]<128)
        remaining=np.zeros_like(old_mask);remaining[confirmed]=[220,35,55,255]
        suspect=(old_mask[:,:,3]>0)&np.all(old_mask[:,:,:3]==[235,140,0],2)
        remaining[suspect]=[235,140,0,255];Image.fromarray(remaining).save(D/f'manual/REMAINING_{n:02d}.png')
    atlas=Image.new('RGB',(1500,2160),(238,235,225))
    text(atlas,20,10,'05 → 06 → 07 → 08 → 09 · ДО / ПИЛОТ · БЕЛЫЙ И РОЗОВЫЙ',25)
    text(atlas,20,49,'Целые холсты 357×358, 1:1. Кадры 05 и 09 не менялись. Пилот не является полной реставрацией.',18)
    for j,n in enumerate([5,6,7,8,9]):
        y=90+j*410;text(atlas,20,y,f'Кадр {n:02d}',18)
        for k,(after,bg,title) in enumerate([(False,'white','До · белый'),(True,'white','Пилот · белый'),(False,(255,0,255),'До · розовый'),(True,(255,0,255),'Пилот · розовый')]):
            x=15+k*372;text(atlas,x,y+25,title,16);atlas.paste(matte(read(n,after),bg),(x,y+49))
    atlas.save(D/'ATLAS_WHITE_PINK.png')
    sheet=Image.new('RGB',(1170,470),(238,235,225));text(sheet,15,10,'ТОЧНЫЕ ПРИНЯТЫЕ ПРАВКИ · ЖЁЛТЫЙ ЦВЕТ — ДИАГНОСТИКА',22)
    for k,n in enumerate([6,7,8]):
        after=matte(read(n,True));arr=np.array(after);patch=np.array(Image.open(D/f'patches/dodge_{n:02d}.png'));arr[patch[:,:,3]>0]=[235,185,0]
        x=15+k*390;text(sheet,x,55,f'Кадр {n:02d}',18);sheet.paste(Image.fromarray(arr),(x,85))
    sheet.save(D/'ACCEPTED_REGIONS.png')
    # Exact paired viewport crops from existing Godot Lab, not PNG projection.
    sheet=Image.new('RGB',(1710,1115),(238,235,225));text(sheet,15,10,'GODOT 4.6.2 · СЛЕВА В ПАРЕ MAIN, СПРАВА ПИЛОТ',24)
    for k,(bg,title) in enumerate([(2,'Белый'),(3,'Ярко-розовый'),(0,'Лесная сцена лаборатории')]):
        capture=Image.open(captures/f'lab-bg{bg}.png').convert('RGB');text(sheet,15+k*565,55,title,19)
        for j,n in enumerate([5,6,7,8,9]):
            y=90+j*200;text(sheet,15+k*565,y,f'Кадр {n:02d} · до / пилот',16)
            sheet.paste(capture.crop((0,j*170,560,j*170+170)),(15+k*565,y+25))
    sheet.save(D/'godot/GODOT_SEQUENCE.png')
    for name in ['arena-06-after.png','arena-07-before.png','arena-07-after.png','arena-08-after.png']:
        shutil.copy2(captures/name,D/'godot'/name)
    shutil.copy2(captures/'godot.log',D/'GODOT_CHECK.log');shutil.copy2(captures/'timeline.json',D/'MOTION_TIMELINE.json')
    # This region metric is diagnostic, not a claim of full artistic continuity.
    union=np.zeros((358,357),bool)
    for n in [6,7,8]:union|=np.array(Image.open(D/f'patches/dodge_{n:02d}.png'))[:,:,3]>0
    pairs=[]
    for n in [5,6,7,8]:
        values=[]
        for after in [False,True]:
            a=np.array(matte(read(n,after))).astype(float);b=np.array(matte(read(n+1,after))).astype(float)
            values.append(float(np.abs(a-b)[union].mean()))
        pairs.append({'from':n,'to':n+1,'main_mean_rgb_step':values[0],'pilot_mean_rgb_step':values[1]})
    (D/'TEMPORAL.json').write_text(json.dumps({'method':'Белый фон, только объединение реально изменённых пикселей; кадры 05–09 имеют один origin [172.5,351]. Не доказательство анатомической правильности или полного отсутствия мерцания.','pairs':pairs},ensure_ascii=False,indent=2)+'\n')
    print('Evidence assembled; source/game PNGs untouched')
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--captures',type=Path,required=True);main(ap.parse_args().captures)
