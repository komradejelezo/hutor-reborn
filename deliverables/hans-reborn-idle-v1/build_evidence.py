#!/usr/bin/env python3
"""Diagnostic layouts only. No game/image-source/animation frame edits."""
from pathlib import Path
import argparse,json,shutil,hashlib
from PIL import Image,ImageDraw,ImageFont
D=Path(__file__).resolve().parent;R=D.parents[1]
def font(n=18):return ImageFont.truetype(str(R/'HutorReborn/assets/fonts/DejaVuSans.ttf'),n)
def text(im,x,y,s,n=18):ImageDraw.Draw(im).text((x,y),s,font=font(n),fill=(20,20,20))
def composite(im,bg='white'):
    image=Image.new('RGBA',im.size,bg);image.alpha_composite(im.convert('RGBA'));return image.convert('RGB')
def main(captures):
    manifest=json.loads((D/'MANIFEST.json').read_text());(D/'godot').mkdir(exist_ok=True)
    for bg,name in [('white','WHITE'),((255,0,255),'PINK'),('black','BLACK')]:
        sheet=Image.new('RGB',(2100,1750),(238,235,225))
        text(sheet,20,12,'ГАНС REBORN · 12 ФАЗ ОБЩЕЙ МОДЕЛИ · '+{'WHITE':'БЕЛЫЙ','PINK':'РОЗОВЫЙ','BLACK':'ЧЁРНЫЙ'}[name],26)
        text(sheet,20,52,'Предпросмотр 40% Nearest; исходные RGBA 1280×1280 в frames/. Полный цикл 3 с, стопы закреплены.',18)
        for i,row in enumerate(manifest['frames']):
            x=15+(i%4)*520;y=90+(i//4)*550
            text(sheet,x,y,f'Кадр {i+1:02d} · {i*.25:.2f} с',17)
            image=Image.open(D/row['file']).convert('RGBA').resize((512,512),Image.Resampling.NEAREST)
            sheet.paste(composite(image,bg),(x,y+25))
        sheet.save(D/('ATLAS_ALL_FRAMES.png' if name=='WHITE' else 'ATLAS_'+name+'.png'))
    for bg,name in [(0,'FOREST'),(1,'WHITE'),(2,'PINK'),(3,'BLACK')]:
        image=Image.open(captures/f'new-bg{bg}.png').convert('RGB')
        sheet=Image.new('RGB',(1200,950),(238,235,225));text(sheet,15,10,'РЕАЛЬНЫЙ GODOT · '+{'FOREST':'ЛЕС','WHITE':'БЕЛЫЙ','PINK':'РОЗОВЫЙ','BLACK':'ЧЁРНЫЙ'}[name],24)
        text(sheet,15,47,'Все 12 кадров, снятые в Godot; данные PNG не заменены технической проекцией.',17)
        sheet.paste(image,(0,90));sheet.save(D/'godot'/f'ALL_FRAMES_{name}.png')
        shutil.copy2(captures/f'comparison-bg{bg}.png',D/'godot'/f'COMPARISON_{name}.png')
    shutil.copy2(captures/'arena.png',D/'godot/FOREST_ARENA.png')
    shutil.copy2(captures/'preview.log',D/'GODOT_CHECK.log')
    shutil.copy2(captures/'motion_checks.json',D/'MOTION_CHECKS.json')
    shutil.copy2(captures/'render.log',D/'RENDER.log')
    paths=['HutorReborn/assets/combat/forest_v2/prepared/Hans/Idle/hans_idle_01.png','HutorReborn/assets/combat/forest_v2/prepared/Hans/Idle/hans_idle_12.png','HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_05.png']
    provenance={'new_art_source':'image_gen, one master only','generated_file':'exec-98af6a05-8c51-43a6-9dc0-b5eb1e600407.png','source_sha256':manifest['source_sha256'],'raw_tool_output_requires_coverage_mask':True,'references':[{'path':p,'sha256':hashlib.sha256((R/p).read_bytes()).hexdigest()} for p in paths],'new_master_not_a_relabelled_old_frame':True,'independent_frame_generation':False,'colour_keying':False,'matte':'provided alpha>=128; separate stored geometry mask; no zero-alpha source pixels filled','authoring':'one reference-based RGBA drawing; local controlled 2D texture rig; all dark RGB retained in native resolution; geometry locks for head/gear/feet','artistic_identity_and_motion_approval':'human approval required before gameplay integration'}
    (D/'SOURCE_PROVENANCE.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    print('Diagnostic atlases and actual Godot evidence saved')
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--captures',type=Path,required=True);main(ap.parse_args().captures)
