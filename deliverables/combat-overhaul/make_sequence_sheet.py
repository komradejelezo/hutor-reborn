#!/usr/bin/env python3
"""Technical PNG contact sheet: production origins/scales, no interpolation.
Not a Godot screenshot or an animation-quality assertion.
"""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[2]
P=R/'HutorReborn/assets/combat/forest_v2'
lib=json.loads((P/'library.json').read_text());rows=[(kind,clip) for kind,clips in lib.items() for clip in clips]
w,h=260,240;sheet=Image.new('RGB',(8*w,h*len(rows)),(220,216,205));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(str(R/'HutorReborn/assets/fonts/DejaVuSans.ttf'),13)
heights={'hans':124,'wolf':76,'leshy':136}
for row,(kind,clip) in enumerate(rows):
    spec=lib[kind][clip];ref=lib[kind]['idle']['frames'][0]['bbox'];scale=heights[kind]/(ref[3]-ref[1])*spec['scale']
    for col in range(8):
        i=round(col*(len(spec['frames'])-1)/7);frame=spec['frames'][i]
        image=Image.open(P/frame['path']).convert('RGBA')
        image=image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.NEAREST)
        x=col*w+w//2;y=row*h+h-20
        sheet.paste(image,(round(x-frame['origin'][0]*scale),round(y-frame['origin'][1]*scale)),image)
        draw.line((col*w+2,y,col*w+w-2,y),fill=(120,135,130))
        draw.text((col*w+5,row*h+3),f'{kind}/{clip} #{i+1}',font=font,fill=(10,10,10))
sheet.save(Path(__file__).parent/'screenshots/registered-sequences.png')
