#!/usr/bin/env python3
"""Focused per-source-frame inventory + source/prepared/Godot evidence.
No game resources are modified. PNG projection columns are technical composites;
the fourth column contains real captures from the existing CombatGraphicsLab.
"""
from pathlib import Path
from io import BytesIO
import argparse,csv,hashlib,json,subprocess,sys
from PIL import Image,ImageDraw,ImageFont
import numpy as np
from scipy import ndimage
R=Path(__file__).resolve().parents[2];P=R/'HutorReborn';PACK=P/'assets/combat/forest_v2';OUT=Path(__file__).parent
sys.path.insert(0,str(P/'tools'))
from restore_hans_combat_frames import expected_outputs,polygon_mask

def show(path):return subprocess.check_output(['git','-C',str(R),'show','ce7e706:HutorReborn/assets/combat/forest_v2/'+path])
def source_number(path):return int(Path(path).stem.rsplit('_',1)[-1])
def project_png(image,frame,scale):
    # Same proportions/origin as production. No material/shader in these columns.
    im=image.convert('RGBA');im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
    canvas=Image.new('RGBA',(280,260),(255,255,255,255))
    canvas.alpha_composite(im,(round(140-frame['origin'][0]*scale),round(223-frame['origin'][1]*scale)))
    return canvas.convert('RGB')
def run(captures):
    lib=json.loads((PACK/'library.json').read_text())['hans'];audits=json.loads((PACK/'source_audit.json').read_text())
    spec_by_clip={a['animation'].split('/')[1].lower():a for a in audits if a['animation'].startswith('Hans/')}
    outputs=expected_outputs();rows=[];(OUT/'frames').mkdir(exist_ok=True)
    font=ImageFont.truetype(str(P/'assets/fonts/DejaVuSans.ttf'),12)
    ref=lib['idle']['frames'][0]['bbox'];ground_scale=124/(ref[3]-ref[1])
    supplemental=[9,10,13,14,15,16]
    for clip,spec in spec_by_clip.items():
        frames=spec['frames'];runtime={f['source']:i+1 for i,f in enumerate(lib[clip]['frames'])}
        sheet=Image.new('RGB',(1120,(260+34)*len(frames)),(235,230,220));draw=ImageDraw.Draw(sheet)
        gpu=Image.open(captures/(clip+'-bg2.png')).convert('RGB');extra=Image.open(captures/'excluded-victory-bg2.png').convert('RGB') if clip=='victory' else None
        for index,frame in enumerate(frames):
            n=source_number(frame['source']);rt=runtime.get(frame['source']);original=Image.open(PACK/frame['source']).convert('RGBA')
            before=Image.open(BytesIO(show(frame['path']))).convert('RGBA');after=Image.open(PACK/frame['path']).convert('RGBA')
            a=np.array(original);b=np.array(before);c=np.array(after);changed=np.any(b!=c,2)
            info=outputs.get(frame['path']);roi=np.zeros(a.shape[:2],bool)
            if info:
                for patch in info['frame']['patches']:roi|=polygon_mask(a.shape[:2],patch['polygon'])
            # Count only reviewed garment interiors, not all transparent canvas.
            core=ndimage.binary_erosion(roi,iterations=3)
            remaining=int((core&(c[:,:,3]<128)&(a[:,:,:3].max(2)==0)).sum()) if roi.any() else None
            alpha_only=int((roi&(b[:,:,3]<128)&(a[:,:,:3].max(2)>0)).sum()) if roi.any() else None
            missing_rgb=int((core&(b[:,:,3]<128)&(a[:,:,:3].max(2)==0)).sum()) if roi.any() else None
            copied=int(info['rgb_mask'].sum()) if info else 0
            changed_n=int(changed.sum());notes=[];artist=False;review=False
            if rt is None:
                status='excluded_source_needs_art';artist=True
                notes.append('Не включён в SpriteFrames: обрезанный кончик меча' if n in [9,10] else 'Не включён в SpriteFrames: меч отсутствует/не соответствует утверждённому действию')
            elif clip=='death':
                status='needs_art';artist=True;notes.append('Подтверждённые внутренние разрывы тела/конечностей; в исходном PNG нет цвета. Безопасный локальный донор не найден. Никакого заполнения чёрным не выполнялось.')
            elif clip=='use_invoke':
                status='needs_art';artist=True;notes.append('Разрывы рукава/ног внутри фигуры; прозрачная магическая аура допустима и не считается повреждением. Геометрия меняется, надёжный перенос не найден.')
            elif changed_n:
                status='locally_repaired';notes.append('Восстановлены только объявленные внутренние участки ткани; весь кадр не объявлен художественно утверждённым.')
            else:
                status='reviewed_unchanged';notes.append('Просмотрен; подтверждённого безопасного ремонта в выбранных участках нет. Существующая подготовка и анимация сохранены.')
            if remaining:
                artist=True;notes.append(f'В глубине проверенных масок осталось {remaining} прозрачных пикселей без RGB; нужны исходные цвета/художник.')
            if clip=='hit' and n in [4,5,6]:
                artist=True;notes.append('Дополнительно остаётся разрыв у живота под рукой; донор с другой позой руки не переносился.')
            if clip=='dodge' and n in [3,4,5,6,7,8,9,10]:
                review=True;notes.append('Боковые просветы между плащом, рукой и бедром требуют художественной оценки; не все они являются дефектами, автоматическое заполнение запрещено.')
            if clip in ['attack','victory','dodge','hit']:
                notes.append('Естественный зазор между ногами и рваная кромка плаща не закрашивались.')
            source_sha=hashlib.sha256((PACK/frame['source']).read_bytes()).hexdigest()
            row={'character':'hans','clip':clip,'source_frame':n,'runtime_frame':rt,'in_runtime':rt is not None,
                'source_png':'HutorReborn/assets/combat/forest_v2/'+frame['source'],'source_mode':Image.open(PACK/frame['source']).mode,
                'prepared_png':'HutorReborn/assets/combat/forest_v2/'+frame['path'],'source_sha256':source_sha,
                'before_sha256':hashlib.sha256(show(frame['path'])).hexdigest(),'after_sha256':hashlib.sha256((PACK/frame['path']).read_bytes()).hexdigest(),
                'status':status,'changed_runtime_pixels':changed_n,'copied_donor_rgb_pixels':copied,
                'retained_rgb_missing_alpha_in_review_roi':alpha_only,'zero_rgb_transparency_before_in_eroded_roi':missing_rgb,
                'zero_rgb_transparency_remaining_in_eroded_roi':remaining,'needs_art':artist,'needs_artist_review':review,
                'size':frame['size'],'origin':frame['origin'],'godot_evidence':'frames/'+clip+'-source-prepared-godot.png',
                'evidence_row_1_based':index+1,'notes':' '.join(notes)}
            if changed_n:
                row['recovered_source_png']='HutorReborn/assets/combat/restoration/hans/recovered_source/'+str(Path(frame['source']).relative_to('assets/Hans'))
            rows.append(row)
            scale=ground_scale*lib[clip]['scale'];y=index*294+34
            for col,image in enumerate([original,before,after]):sheet.paste(project_png(image,frame,scale),(col*280,y))
            if rt:
                cell=rt-1;x=(cell%4)*560+280;sy=(cell//4)*260;render=gpu.crop((x,sy,x+280,sy+260))
            else:
                cell=supplemental.index(n);x=(cell%4)*560+280;sy=(cell//4)*260;render=extra.crop((x,sy,x+280,sy+260))
            sheet.paste(render,(840,y))
            labels=[f'{clip} source #{n:02d} RAW',f'main #{n:02d} (runtime {rt or "excluded"})',f'repaired #{n:02d}: {changed_n}px',f'Godot #{n:02d} WHITE']
            for col,text in enumerate(labels):draw.text((col*280+4,index*294+4),text,font=font,fill=(15,15,15))
            draw.text((4,index*294+19),'PNG columns: registered technical projection; last column: actual existing Lab capture',font=font,fill=(45,45,45))
        sheet.save(OUT/'frames'/(clip+'-source-prepared-godot.png'))
    fields=list(rows[0].keys());extra_keys=set().union(*(row.keys() for row in rows))-set(fields);fields+=sorted(extra_keys)
    with (OUT/'FRAME_INVENTORY.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');writer.writeheader();writer.writerows(rows)
    (OUT/'frame_inventory.json').write_text(json.dumps({'baseline':'ce7e706','convention':'All frame numbers are original source filename indices; runtime_frame explicitly maps the curated Victory clip. Natural air gaps are not automatically defects.','frames':rows},ensure_ascii=False,indent=2)+'\n')
    lines=['# Покадровый перечень Ганса','', 'Номера — из исходных имён файлов, от 1. Victory runtime 9/10 соответствует source 11/12. В таблице отдельно отмечены неигровые кадры. Полные пути и метрики — в CSV/JSON.','', '| Клип | Исходный кадр | Кадр в игре | Изменено px / RGB донора | Статус | Остаток без RGB в проверенной маске | Действие |','|---|---:|---:|---:|---|---:|---|']
    for r in rows:
        action='Художественное восстановление' if r['needs_art'] else 'Художественная оценка спорных просветов' if r['needs_artist_review'] else 'Без дополнительных изменений'
        lines.append(f"| {r['clip']} | {r['source_frame']:02d} | {r['runtime_frame'] or 'исключён'} | {r['changed_runtime_pixels']} / {r['copied_donor_rgb_pixels']} | {r['status']} | {r['zero_rgb_transparency_remaining_in_eroded_roi'] if r['zero_rgb_transparency_remaining_in_eroded_roi'] is not None else 'не считалось'} | {action} |")
    lines+=['','## Точные файлы для художественного восстановления','']
    for r in rows:
        if r['needs_art']:lines.append(f"- `{r['source_png']}` — source {r['source_frame']:02d}, runtime {r['runtime_frame'] or 'не используется'}: {r['notes']}")
    lines+=['','## Спорные просветы, не признанные автоматически дефектами','']
    for r in rows:
        if r['needs_artist_review']:lines.append(f"- `{r['source_png']}` — проверить отделение плаща/руки/бедра по референсу; естественный воздух и рваную ткань не закрашивать.")
    (OUT/'FRAME_INVENTORY.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'source_frames':len(rows),'runtime_frames':sum(r['in_runtime'] for r in rows),'changed_frames':sum(r['changed_runtime_pixels']>0 for r in rows),'changed_pixels':sum(r['changed_runtime_pixels'] for r in rows),'donor_rgb_pixels':sum(r['copied_donor_rgb_pixels'] for r in rows),'needs_art':sum(r['needs_art'] for r in rows)},ensure_ascii=False))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--captures',type=Path,required=True);run(parser.parse_args().captures)
