#!/usr/bin/env python3
"""Read-only combat graphics audit. Findings are candidates, not anatomy judgements.

Requires Pillow/numpy/scipy. Run from any directory; --output is an artifact
folder, never a source atlas. Exit 1 means structural errors, not review flags.
"""
from pathlib import Path
from functools import lru_cache
import argparse,json,re
import numpy as np
from PIL import Image
from scipy import ndimage as nd
P=Path(__file__).resolve().parents[1]

def inspect_image(image):
    a=np.array(image.convert('RGBA'));alpha=a[:,:,3];support=alpha>40
    y,x=np.nonzero(support)
    if len(x)==0:return {'empty':True,'opaque':0,'coverage':0,'bbox':None,'holes':0,'hole_pixels':0,'edge_pixels':0,'dark_edge':0}
    bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
    holes=nd.binary_fill_holes(support)&~support;labels,n=nd.label(holes)
    sizes=np.bincount(labels.ravel())[1:];large=sizes[sizes>=3]
    edge=support&~nd.binary_erosion(support)
    dark=edge&(alpha<245)&(a[:,:,:3].max(2)<20)
    return {'empty':False,'opaque':int((alpha==255).sum()),'coverage':int(support.sum()),'bbox':bbox,
        'holes':int(len(large)),'hole_pixels':int(large.sum()),'edge_pixels':int(support[0].sum()+support[-1].sum()+support[:,0].sum()+support[:,-1].sum()),
        'alpha_mass':round(float(alpha.sum())/255,2),'dark_edge':int(dark.sum()),'semi':int(((alpha>0)&(alpha<255)).sum()),'mode':image.mode,'alpha_channel':image.mode in ['RGBA','LA'] or 'transparency' in image.info,'size':list(image.size)}

@lru_cache(maxsize=12)
def opened(path):return Image.open(path).copy()
def native_frames(path):
    text=path.read_text();atlas=re.search(r'path="res://([^"]+\.png)"',text)[1]
    regions={m[1]:[int(v) for v in m[2].split(', ')] for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s+atlas = [^\n]+\s+region = Rect2\(([^)]+)\)',text)}
    result={}
    for part in text.split('"frames": [')[1:]:
        name=re.search(r'"name": &"([^"]+)"',part)
        if name:result[name[1]]=[{'path':atlas,'crop':regions[i]} for i in re.findall(r'SubResource\("([^"]+)"\)',part.split('],')[0])]
    return result

def runtime_sequences():
    result={};lib=json.loads((P/'assets/combat/forest_v2/library.json').read_text())
    units=json.loads((P/'data/combat/prototype.json').read_text())['units']
    for kind,unit in units.items():
        key='leshy' if kind=='beast' else kind
        if key in lib:
            clips={}
            for clip,spec in lib[key].items():
                frames=[{'path':'assets/combat/forest_v2/'+f['path'],'origin':f['origin'],'scale':spec['scale'],'source':f['source'],'expected_size':f['size']} for f in spec['frames']]
                clips[clip]=frames
            result[kind]=clips
        elif 'frames' in unit:
            path=P/'assets/combat/readability'/f'{kind}_frames.tres'
            if not path.is_file():path=P/unit['frames'].removeprefix('res://')
            try:result[kind]=native_frames(path)
            except (FileNotFoundError,TypeError,KeyError,IndexError):result[kind]={'unavailable_spriteframes':[{'path':str(path.relative_to(P))}]}
        else:
            fixed=f'assets/combat/readability/{kind}.png'
            result[kind]={'default':[{'path':fixed if (P/fixed).exists() else unit['image'].removeprefix('res://')}]}
    return result

def run(output):
    findings=[];metrics=[];total=0;cache={}
    def finding(kind,clip,index,f,code,severity,detail):
        findings.append({'character':kind,'animation':clip,'frame':index+1,'file':f['path'],'type':code,'severity':severity,'detail':detail})
    for kind,clips in runtime_sequences().items():
        for clip,frames in clips.items():
            previous=None
            for index,f in enumerate(frames):
                total+=1;path=P/f['path']
                if f.get('source') and not (P/'assets/combat/forest_v2'/f['source']).is_file():
                    finding(kind,clip,index,f,'missing_source','error',f['source'])
                if not path.is_file():finding(kind,clip,index,f,'missing','error','Runtime texture is absent');continue
                key=(str(path),tuple(f.get('crop',[])))
                if key not in cache:
                    try:im=opened(path)
                    except Exception as exc:
                        finding(kind,clip,index,f,'invalid_image','error',str(exc));continue
                    if 'crop' in f:
                        x,y,w,h=f['crop']
                        if min(x,y)<0 or min(w,h)<=0 or x+w>im.width or y+h>im.height:
                            finding(kind,clip,index,f,'invalid_crop','error',str(f['crop']));continue
                        im=im.crop((x,y,x+w,y+h))
                    cache[key]=inspect_image(im)
                m=cache[key];metrics.append({'character':kind,'animation':clip,'frame':index+1,'file':f['path'],**m})
                if not m.get('alpha_channel') and not m['empty']:finding(kind,clip,index,f,'missing_alpha','error','Runtime fighter texture has no alpha channel: '+str(m.get('mode')))
                if f.get('expected_size') and m.get('size')!=f['expected_size']:finding(kind,clip,index,f,'size_mismatch','error',str(m.get('size'))+' expected '+str(f['expected_size']))
                if m['empty']:finding(kind,clip,index,f,'empty','error','No visible alpha>40 pixels');continue
                if m['coverage']<30:finding(kind,clip,index,f,'near_empty','error',str(m['coverage'])+' visible pixels')
                if m['edge_pixels']:finding(kind,clip,index,f,'border_contact','review',str(m['edge_pixels'])+' visible pixels touch the source/crop boundary; inspect limb/tool/VFX clipping')
                if m['holes']:finding(kind,clip,index,f,'interior_gap','review',str(m['holes'])+' enclosed gaps >=3px, '+str(m['hole_pixels'])+'px total. May be legitimate staff/limb/foliage gaps; never auto-fill.')
                if m['dark_edge']>10:finding(kind,clip,index,f,'dark_aa','review',str(m['dark_edge'])+' dark semi-transparent edge pixels: inspect on white/magenta, not proof of a halo/premultiplication')
                if m['opaque']<m['coverage']*.45:finding(kind,clip,index,f,'low_opaque_coverage','review','Less than 45% of supported pixels are fully opaque; inspect original alpha and effects')
                bbox=m['bbox'];origin=f.get('origin',[m['size'][0]/2,bbox[3]])
                scale=f.get('scale',1)
                center=[((bbox[0]+bbox[2])/2-origin[0])*scale,(bbox[3]-origin[1])*scale]
                current={'area':m['coverage'],'alpha_mass':m['alpha_mass'],'center':center,'height':(bbox[3]-bbox[1])*scale,'size':m['size']}
                if previous:
                    area=abs(current['area']/previous['area']-1)
                    alpha_mass=abs(current['alpha_mass']/max(1,previous['alpha_mass'])-1)
                    shift=sum((x-y)**2 for x,y in zip(center,previous['center']))**.5
                    height=abs(current['height']/max(1,previous['height'])-1)
                    if current['size']!=previous['size']:finding(kind,clip,index,f,'canvas_change','review','Different source dimensions; check registered AtlasTexture margin/origin')
                    if area>.28 or alpha_mass>.28 or shift>14 or height>.18:finding(kind,clip,index,f,'temporal_jump','review',f'vs previous: alpha area {area:.1%}, opacity mass {alpha_mass:.1%}, registered center/foot {shift:.1f} source-px, height {height:.1%}. Death/action changes can be intentional.')
                previous=current
    # Inventory every supplied battle PNG, including intentionally excluded poses.
    inventory=[]
    for folder in ['assets/combat']:
        for path in sorted((P/folder).rglob('*.png')):
            try:
                with Image.open(path) as im:
                    im.verify()
                with Image.open(path) as im:inventory.append({'file':str(path.relative_to(P)),'size':list(im.size),'mode':im.mode,'alpha_channel':im.mode in ['RGBA','LA'] or 'transparency' in im.info})
            except Exception as exc:findings.append({'file':str(path.relative_to(P)),'type':'invalid_png','severity':'error','detail':str(exc)})
    import_errors=[]
    for folder in ['assets/combat/forest_v2/prepared','assets/combat/readability']:
        for path in (P/folder).rglob('*.png.import'):
            text=path.read_text()
            for flag in ['process/premult_alpha=false','process/fix_alpha_border=false','mipmaps/generate=false']:
                if flag not in text:import_errors.append({'file':str(path.relative_to(P)),'type':'import_flag','severity':'error','detail':flag+' required'})
    findings+=import_errors
    counts={level:sum(f['severity']==level for f in findings) for level in ['error','review']}
    result={'runtime_frames':total,'unique_runtime_crops':len(cache),'png_inventory':inventory,'counts':counts,'limitations':['Interior gaps and temporal jumps are review candidates, not automatic defects.','No semantic anatomy/tool/hand consistency inference. Inspect movement and white/magenta backgrounds in CombatGraphicsLab.','Native woodcutter/herbalist work clips are world animations, not newly authored combat Attack/Hit/Death. Spirit/mercenary have only one approved pose.'],'metrics':metrics,'findings':findings}
    output.mkdir(parents=True,exist_ok=True)
    (output/'graphics_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    lines=['# Автоматический аудит боевой графики','',f"Проверено: {total} кадров в последовательностях, {len(cache)} уникальных текстур/областей, {len(inventory)} исходных и производных PNG.",f"Структурных ошибок: **{counts['error']}**. Кандидатов на визуальный просмотр: **{counts['review']}**.",'','Это анализ файлов, а не подтверждение качества движения. Открытые промежутки между ветвями, оружием и телом допустимы. Автоматическое заполнение не выполняется.','', 'Полная таблица метрик и каждого кадра — `graphics_audit.json`.','', '| Персонаж | Анимация | Кадр | Тип | Файл | Причина |','|---|---|---:|---|---|---|']
    lines += [f"| {f.get('character','—')} | {f.get('animation','—')} | {f.get('frame','—')} | {f['severity']}: {f['type']} | `{f['file']}` | {f['detail']} |" for f in findings]
    lines+=['','## Ограничения','']+['- '+s for s in result['limitations']]
    (output/'GRAPHICS_AUDIT.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'runtime_frames':total,'unique_runtime_crops':len(cache),'png_inventory':len(inventory),**counts}))
    return counts['error']
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=P.parent/'deliverables/combat-overhaul');args=parser.parse_args();raise SystemExit(bool(run(args.output)))
