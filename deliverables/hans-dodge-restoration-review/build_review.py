#!/usr/bin/env python3
"""Read-only game input -> Russian artist-review atlases, masks and reports.

Only this deliverable directory is written. No inpainting, donor transfer,
image-keying, changes to alpha, origins, SpriteFrames or game settings.
"""
from pathlib import Path
from io import BytesIO
import argparse,hashlib,json,subprocess,textwrap
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
PACK=ROOT/'HutorReborn/assets/combat/forest_v2'
BEFORE='ce7e70600d10f2d534ea539090da2c8bf68d46b6'
AFTER='6ef9994e066bda3ab5a65135da26593e5be805e1'
FONT=ROOT/'HutorReborn/assets/fonts/DejaVuSans.ttf'
COLORS={1:(220,35,55),2:(235,140,0),3:(0,145,200),4:(100,155,55)}
NAMES={1:'Подтверждённый остаток',2:'Подозрение: нужна оценка',3:'Естественный просвет',4:'Рваная кромка плаща'}
NEAREST=Image.Resampling.NEAREST
REGIONS={
 'К':[[231,219],[251,218],[264,230],[263,245],[254,258],[239,254],[226,240]],
 'Ж':[[164,159],[187,156],[211,167],[218,181],[205,191],[179,191],[164,178]],
 'П':[[164,190],[192,190],[211,204],[202,218],[170,211]],
}
# Artist inspection envelopes, selected after viewing all twelve source-sized
# poses on white. These rectangles are NOT asserted silhouette reconstruction.
# x0,y0,x1,y1: origin top-left; right/bottom EXCLUSIVE, before registration.
THIGH={1:[124,238,166,260],2:[120,235,164,258],3:[117,232,170,259],4:[111,230,171,258],5:[111,228,173,257],6:[104,231,169,258],7:[103,230,171,258],8:[104,230,170,258],9:[107,230,170,258],10:[111,237,171,260],11:[116,240,172,268],12:[122,241,177,267]}
ARMPIT={1:[112,169,141,222],2:[113,174,143,222],3:[105,162,145,224],4:[104,163,151,228],5:[103,173,147,230],6:[133,150,174,197],7:[104,170,133,218],8:[111,190,135,229],9:[110,188,135,231],10:[112,199,143,240],11:[113,190,140,239],12:[110,188,144,238]}
RIGHT={1:[215,125,248,174],2:[215,132,253,180],3:[223,140,266,194],4:[227,151,278,211],5:[216,145,275,207],6:[217,150,292,220],7:[232,157,302,223],8:[230,162,306,222],9:[231,153,301,216],10:[221,128,277,199],11:[214,119,267,181],12:[221,113,278,185]}
HEM={1:[40,265,91,302],2:[32,262,83,302],3:[14,246,74,293],4:[8,249,65,291],5:[8,252,65,292],6:[8,246,74,292],7:[16,247,80,293],8:[10,250,74,293],9:[10,252,74,294],10:[10,250,74,295],11:[24,258,87,302],12:[28,260,91,305]}

def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args])
def sha(data):return hashlib.sha256(data).hexdigest()
def font(n=18):return ImageFont.truetype(str(FONT),n)
def text(im,xy,s,n=18,color=(25,25,25)):
    ImageDraw.Draw(im).text(xy,str(s),font=font(n),fill=color)
def wrap(im,xy,s,width=105,n=16,color=(25,25,25)):
    for i,line in enumerate(textwrap.wrap(s,width=width)):text(im,(xy[0],xy[1]+i*(n+5)),line,n,color)
def matte(im,bg=(255,255,255)):
    base=Image.new('RGBA',im.size,(*bg,255));base.alpha_composite(im.convert('RGBA'));return base.convert('RGB')
def polygon(vertices):
    m=Image.new('1',(357,358));ImageDraw.Draw(m).polygon([tuple(v) for v in vertices],fill=1);return np.array(m,bool)
def rect_vertices(box):
    x0,y0,x1,y1=box;return [[x0,y0],[x1-1,y0],[x1-1,y1-1],[x0,y1-1]]
def bbox(mask):
    y,x=np.where(mask)
    return [int(x.min()),int(y.min()),int(x.max())+1,int(y.max())+1] if len(x) else None
def edge_info(a):
    visible=a[:,:,3]>=128
    return {name:{'count':int(v.sum()),'positions':np.flatnonzero(v).tolist()} for name,v in [('верх',visible[0]),('низ',visible[-1]),('лево',visible[:,0]),('право',visible[:,-1])]}
def paste_full(sheet,im,x,y,origin=None,bg=(255,255,255)):
    sheet.paste(matte(im,bg),(x,y))
    if origin:
        d=ImageDraw.Draw(sheet);ox=x+origin[0];oy=y+origin[1]
        d.line((ox-9,oy,ox+9,oy),fill=(55,160,180),width=1)
        d.line((ox,oy-5,ox,oy+5),fill=(55,160,180),width=1)
def coloured(labels):
    a=np.zeros((358,357,4),np.uint8)
    for key,color in COLORS.items():a[labels==key]=[*color,255]
    return Image.fromarray(a)
def overlay(image,labels):
    im=matte(image);a=np.array(im)
    for key,color in COLORS.items():a[labels==key]=np.array(color,np.uint8)
    return Image.fromarray(a)
def numbered_page(name,page):return OUT/(name+'.png' if page==0 else f'pages/{name}_{page+1:02d}.png')
def add_legend(sheet,y):
    d=ImageDraw.Draw(sheet)
    for i,key in enumerate(NAMES):
        x=20+i*370;d.rectangle((x,y,x+16,y+16),fill=COLORS[key]);text(sheet,(x+23,y-2),NAMES[key],16)

def build(captures):
    assert not git('diff',AFTER,'--','HutorReborn'),'Game files differ from stated merged main baseline'
    lib=json.loads((PACK/'library.json').read_text())['hans'];frames=lib['dodge']['frames']
    assert len(frames)==12 and lib['dodge']['used_indices']==list(range(1,13))
    recipe=json.loads((ROOT/'HutorReborn/assets/combat/restoration/hans/recipe.json').read_text())
    recipes={r['path']:r for r in recipe['frames'] if r['clip']=='dodge'}
    provenance=json.loads((ROOT/'HutorReborn/assets/combat/restoration/hans/provenance.json').read_text())
    prior={r['path']:r for r in provenance['frames']}
    for sub in ['pages','masks','godot']: (OUT/sub).mkdir(exist_ok=True)
    all_rows=[];images=[]
    for i,f in enumerate(frames,1):
        raw=Image.open(PACK/f['source']).convert('RGBA')
        old=Image.open(BytesIO(git('show',BEFORE+':HutorReborn/assets/combat/forest_v2/'+f['path']))).convert('RGBA')
        current=Image.open(PACK/f['path']).convert('RGBA')
        assert raw.size==old.size==current.size==(357,358)
        a=np.array(raw);b=np.array(old);c=np.array(current);labels=np.zeros((358,357),np.uint8)
        regions=[];domains=recipes.get(f['path'],{}).get('patches',[])
        # Confirmed means the surviving INTERIOR part of a previously reviewed
        # garment polygon, eroded by three pixels; never a generated silhouette.
        for key,points in REGIONS.items():
            reviewed=any(p['polygon']==points for p in domains)
            if not reviewed:continue
            scope=ndimage.binary_erosion(polygon(points),iterations=3)
            pixels=scope&(c[:,:,3]<128);labels[pixels]=1
            regions.append({'id':key,'category':'подтверждённый остаток' if pixels.any() else 'внутри прежней маски остаток не обнаружен','confidence':'высокая для выбранного ядра; граница новой ткани не утверждена','polygon':points,'erosion_pixels':3,'bbox_of_nonzero_mask':bbox(pixels),'low_alpha_pixels':int(pixels.sum()),'raw_zero_rgb_pixels':int((pixels&(a[:,:,:3].max(2)==0)).sum()),'raw_retained_rgb_pixels':int((pixels&(a[:,:,:3].max(2)>0)).sum()),'neighbour_recovery':'Надёжного полного донора для остатка в PR №42 не найдено; повторное совмещение не выполнялось.' if pixels.any() else 'Остаточного участка в этом ядре нет.','artist_required':bool(pixels.any())})
        for key,box,cat,confidence,comment in [
            ('Б',THIGH[i],2,'средняя','Разрыв над верхом дальней голени/бедра: ткань, край полы и воздух накладываются. Нужна оценка художника; весь прямоугольник тканью не считать.'),
            ('Л',ARMPIT[i],2,'низкая/средняя','Просвет со стороны руки с мечом. Возможно естественное отделение согнутой руки или полы; не заполнять автоматически.'),
            ('В',RIGHT[i],3,'средняя','Воздух между свободной рукой и корпусом преимущественно естественный. Отдельные края ткани внутри окна остаются спорными.'),
            ('Н',[174,282,215,309],3,'высокая для центральной части','Центральный воздух между разнесёнными ногами; не продолжать в него ткань.'),
            ('Р',HEM[i],4,'средняя','Пример художественно рваной нижней кромки плаща; не выпрямлять край и не закрашивать фон.')]:
            scope=polygon(rect_vertices(box));pixels=scope&(c[:,:,3]<128)&(labels==0)
            labels[pixels]=cat
            regions.append({'id':key,'category':NAMES[cat],'confidence':confidence,'inspection_box':box,'bbox_of_nonzero_mask':bbox(pixels),'low_alpha_pixels':int(pixels.sum()),'raw_zero_rgb_pixels':int((pixels&(a[:,:,:3].max(2)==0)).sum()),'raw_retained_rgb_pixels':int((pixels&(a[:,:,:3].max(2)>0)).sum()),'interpretation':comment,'neighbour_recovery':'До утверждения контура перенос из соседней позы не разрешён.' if cat==2 else 'Не восстанавливать: контекст для защиты естественных просветов/края.','artist_required':'сначала подтвердить диагноз' if cat==2 else False})
        mask=coloured(labels);mask.save(OUT/f'masks/dodge_{i:02d}.png')
        assert mask.size==(357,358)
        changed=np.any(b!=c,2);rgb_changed=np.any(b[:,:,:3]!=c[:,:,:3],2)
        previous=prior.get(f['path'],{})
        assert int(changed.sum())==previous.get('changed_pixels',0)
        assert int(rgb_changed.sum())==previous.get('donor_rgb_pixels',0)
        row={'source_frame':i,'runtime_frame':i,'source_png':'HutorReborn/assets/combat/forest_v2/'+f['source'],'before_png_git':BEFORE+':HutorReborn/assets/combat/forest_v2/'+f['path'],'current_png':'HutorReborn/assets/combat/forest_v2/'+f['path'],'size':f['size'],'origin':f['origin'],'source_sha256':sha((PACK/f['source']).read_bytes()),'before_sha256':sha(git('show',BEFORE+':HutorReborn/assets/combat/forest_v2/'+f['path'])),'current_sha256':sha((PACK/f['path']).read_bytes()),'previously_repaired_pixels':int(changed.sum()),'previous_donor_rgb_pixels':int(rgb_changed.sum()),'previous_alpha_only_pixels':int(changed.sum()-rgb_changed.sum()),'remaining_confirmed_mask_pixels':int((labels==1).sum()),'suspected_mask_pixels':int((labels==2).sum()),'regions':regions,'mask_png':f'masks/dodge_{i:02d}.png','damage_page':str(numbered_page('ATLAS_DAMAGE',(i-1)//4).relative_to(OUT)),'before_after_page':str(numbered_page('ATLAS_BEFORE_AFTER',(i-1)//3).relative_to(OUT))}
        row['previous_repairs']=previous.get('trace',[])
        row['border_audit']={'source_top_row_black_matte_pixels':int(((a[0,:,3]>=128)&(a[0,:,:3].max(1)<=8)).sum()),'source_edges':edge_info(a),'current_edges':edge_info(c),'edge_pixels_unchanged_by_pr42':bool(np.array_equal(b[0],c[0]) and np.array_equal(b[-1],c[-1]) and np.array_equal(b[:,0],c[:,0]) and np.array_equal(b[:,-1],c[:,-1])),'diagnosis':'Контакт с краем — повод осмотра, не доказательство обрезанной конечности. Чёрная горизонтальная подложка RAW не является тканью; часть удалена прежней подготовкой до PR №42.'}
        all_rows.append(row);images.append((raw,old,current,labels,changed))
    # All frames: chronological order, three full-size unshifted source canvases
    # per pose. Registration marker is an annotation, not painted into the PNG.
    sheet=Image.new('RGB',(3320,1840),(238,235,226))
    text(sheet,(20,12),'АТЛАС №1 · ВСЕ 12 ИГРОВЫХ КАДРОВ УКЛОНЕНИЯ',26)
    text(sheet,(20,51),'Каждый холст 357 × 358, масштаб 1:1. Белый / ярко-розовый / чёрный. Голубая метка — исходная точка опоры.',18)
    for index,(row,data) in enumerate(zip(all_rows,images)):
        x=15+(index%3)*1100;y=95+(index//3)*435
        text(sheet,(x,y),f'Исходный {index+1:02d} = игровой {index+1:02d}; опора {row["origin"]}',18)
        for k,(name,bg) in enumerate([('Белый',(255,255,255)),('Ярко-розовый',(255,0,255)),('Чёрный',(0,0,0))]):
            text(sheet,(x+k*365,y+26),name,16);paste_full(sheet,data[2],x+k*365,y+52,row['origin'],bg)
    sheet.save(OUT/'ATLAS_ALL_FRAMES.png')
    # Damage atlas: originals/current plus native-coordinate crops at exactly 4x.
    crops=[('Корпус и пояс',[136,135,236,235]),('Ближнее колено',[215,207,287,279]),('Дальнее бедро и край полы',[104,225,176,297])]
    for page in range(3):
        sheet=Image.new('RGB',(1890,2180),(238,235,226))
        text(sheet,(20,12),f'АТЛАС №2 · ПОВРЕЖДЕНИЯ · СТРАНИЦА {page+1} / 3',25)
        text(sheet,(20,48),'Полные холсты слева — 1:1; увеличения справа — 4× Nearest. Окна осмотра не равны маске дорисовки.',17)
        for j in range(4):
            index=page*4+j;raw,old,current,labels,changed=images[index];y=85+j*520
            text(sheet,(20,y),f'Кадр {index+1:02d} · оригинал',18);paste_full(sheet,raw,20,y+52)
            text(sheet,(397,y),'Текущий игровой PNG',18);paste_full(sheet,current,397,y+52)
            for k,(title,box) in enumerate(crops):
                x=[780,1200,1540][k];text(sheet,(x,y),title,16);text(sheet,(x,y+24),f'Окно {box}; 4×',14)
                crop=matte(current.crop(box)).resize(((box[2]-box[0])*4,(box[3]-box[1])*4),NEAREST);sheet.paste(crop,(x,y+52))
            text(sheet,(20,y+462),f'Ранее исправлено: {all_rows[index]["previously_repaired_pixels"]} px. Подтверждённый остаток в выбранных ядрах: {all_rows[index]["remaining_confirmed_mask_pixels"]} px.',17)
            text(sheet,(20,y+488),'Белые окна у рук, между ногами и на краю плаща не признаны всеобщей потерей ткани.',16)
        sheet.save(numbered_page('ATLAS_DAMAGE',page))
    # Fair comparison: prepared-before vs prepared-current, NEVER raw vs prepared.
    for page in range(4):
        sheet=Image.new('RGB',(1570,1430),(238,235,226))
        text(sheet,(20,12),f'АТЛАС №3 · ДО / ПОСЛЕ PR №42 · СТРАНИЦА {page+1} / 4',25)
        text(sheet,(20,49),'Размер и опора сохранены. Бирюза — реально изменённые пиксели; красный/оранжевый справа — остаток/подозрение.',16)
        for j in range(3):
            index=page*3+j;raw,old,current,labels,changed=images[index];y=85+j*440
            text(sheet,(20,y),f'Кадр {index+1:02d} · до PR №42',18);paste_full(sheet,old,20,y+55)
            text(sheet,(407,y),'После PR №42 (main)',18);paste_full(sheet,current,407,y+55)
            text(sheet,(794,y),'Точная разница PR №42',18)
            delta=Image.new('RGB',(357,358),(40,40,40));da=np.array(delta);da[changed]=(0,220,225);sheet.paste(Image.fromarray(da),(794,y+55))
            text(sheet,(1181,y),'Осталось / проверить',18)
            residual=np.where(np.isin(labels,[1,2]),labels,0).astype(np.uint8)
            sheet.paste(overlay(current,residual),(1181,y+55))
            text(sheet,(20,y+418),f'Исправлено {all_rows[index]["previously_repaired_pixels"]} px; RGB из соседних кадров: {all_rows[index]["previous_donor_rgb_pixels"]} px.',16)
        sheet.save(numbered_page('ATLAS_BEFORE_AFTER',page))
    sheet=Image.new('RGB',(1570,1835),(238,235,226))
    text(sheet,(20,12),'АТЛАС №4 · МАСКИ ДЛЯ ХУДОЖЕСТВЕННОГО РАССМОТРЕНИЯ',25)
    add_legend(sheet,55)
    text(sheet,(20,85),'Не готовые маски заливки. Отмечены лишь пиксели alpha <128 внутри указанных областей; за пределами масок диагноз не задан.',16)
    for index,data in enumerate(images):
        x=20+(index%4)*390;y=123+(index//4)*560;current=data[2];labels=data[3]
        text(sheet,(x,y),f'Кадр {index+1:02d}',19);sheet.paste(overlay(current,labels),(x,y+37))
        text(sheet,(x,y+407),f'Подтверждено в ядрах: {(labels==1).sum()} px',15)
        text(sheet,(x,y+432),f'Подозрение: {(labels==2).sum()} px',15)
        wrap(sheet,(x,y+459),'Маска 357 × 358, начало (0,0) сверху слева. Цвет — категория диагноза, не новая ткань.',width=37,n=14)
    sheet.save(OUT/'ATLAS_MASKS.png')
    # Approved Idle is an appearance reference only, never substituted for Dodge.
    sheet=Image.new('RGB',(2700,650),(238,235,226))
    text(sheet,(20,12),'ЭТАЛОН ВНЕШНОСТИ · УТВЕРЖДЁННЫЙ HANS IDLE V2 STABILIZED',26)
    text(sheet,(20,52),'Только одежда, цвета, снаряжение и лицо. Эти позы не являются заменой уклонения и не задают контур согнутого тела.',18)
    for k,index in enumerate([0,11,23]):
        f=lib['idle']['frames'][index];im=Image.open(PACK/f['path']).convert('RGBA')
        x=20+k*890;text(sheet,(x,105),f'Покой: исходный кадр {index+1:02d}; 2× Nearest',20)
        text(sheet,(x,139),f'Размер {f["size"]}; опора {f["origin"]}',16)
        sheet.paste(matte(im).resize((im.width*2,im.height*2),NEAREST),(x,182))
    sheet.save(OUT/'HANS_IDLE_REFERENCE.png')
    # Fresh Godot evidence labels are Russian; content regions are unresampled
    # crops from actual paired Lab viewport screenshots.
    for bg,name in [(2,'БЕЛЫЙ'),(3,'РОЗОВЫЙ'),(1,'ЧЁРНЫЙ')]:
        capture=Image.open(captures/f'godot-bg{bg}.png').convert('RGB')
        sheet=Image.new('RGB',(1140,1270),(238,235,226))
        text(sheet,(10,10),f'РЕАЛЬНЫЙ GODOT 4.6.2 · {name} ФОН · ВСЕ 12 КАДРОВ',22)
        text(sheet,(10,43),'Слева в каждой паре: до PR №42. Справа: текущий PNG. Рабочий материал, масштаб и опора.',16)
        for i in range(12):
            x=10+(i%2)*560;y=80+(i//2)*195
            text(sheet,(x,y),f'Кадр {i+1:02d} · до / после',16)
            sheet.paste(capture.crop(((i%2)*560,(i//2)*170,(i%2)*560+560,(i//2)*170+170)),(x,y+23))
        sheet.save(OUT/f'godot/ФОН_{name}.png')
    document={'title':'Ганс: атлас уклонения перед художественной реставрацией','main_commit':AFTER,'before_pr42_commit':BEFORE,'coordinates':'Исходный PNG 357×358; (0,0) сверху слева; x вправо, y вниз; bbox [x0,y0,x1,y1), правая/нижняя границы исключены. Origin из library.json, без переноса изображения.','diagnostic_alpha_threshold':128,'mask_palette':{str(k):{'rgb':v,'meaning':NAMES[k]} for k,v in COLORS.items()},'mask_warning':'Это аннотированные окна осмотра, не утверждённая новая геометрия тела. Подозрительные маски нельзя использовать для автоматического заполнения. Нулевой RGB сам по себе не доказывает потерю ткани.','animation':{k:v for k,v in lib['dodge'].items() if k!='frames'},'frames':all_rows}
    (OUT/'FRAME_REPORT.json').write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    write_report(document)
    return document

def write_report(doc):
    lines=['# Ганс — покадровый атлас Dodge перед художественной реставрацией','',
      f'Основа: `main` `{AFTER[:7]}` после объединённого PR №42. Версия до PR №42: `{BEFORE[:7]}`. 20 ноября 2026.','',
      'Проанализированы все **12** зарегистрированных игровых кадров. Исходный и игровой номера совпадают (01–12). Текущие игровые PNG не изменялись. Это подготовка к художественному решению; новые ткани, силуэты и кадры не создавались.','',
      '## Как читать материалы','',
      '- [Все кадры](ATLAS_ALL_FRAMES.png): целые исходные холсты текущих PNG на трёх контрастных фонах, масштаб 1:1, неизменённые пропорции. Метка опоры — поверхностная подпись атласа.','- [Повреждения](ATLAS_DAMAGE.png), продолжения в `pages/`: исходник и текущий PNG, три окна каждого кадра при 4× Nearest.','- [До/после](ATLAS_BEFORE_AFTER.png), продолжения в `pages/`: именно старый подготовленный PNG против текущего; отдельная точная разница PR №42.','- [Маски](ATLAS_MASKS.png), исходный размер в `masks/`: красный — остаток в ранее проверенном ядре ткани; оранжевый — подозрение; голубой — естественный воздух; зелёный — рваная кромка. Маски не утверждены для заливки.','- [Покой как эталон внешности](HANS_IDLE_REFERENCE.png): лицо, плащ, кожа, ремни, снаряжение и цвета; не переносить геометрию прямой позы на согнутый корпус.','- Свежие [снимки Godot](godot/), [видео](DODGE_COMPARISON.mp4) и журнал проверки показывают рабочий материал. Атласы PNG являются техническими композициями, а не скриншотами Godot.','',
      '## Диагноз и границы уверенности','',
      'Чёрный фон скрывает прозрачные провалы. Белый и ярко-розовый выявляют их. Проверка использует alpha <128 только внутри явно выбранных областей, а не по всему прозрачному фону. Тонкая частичная alpha на настоящем контуре может быть сглаживанием и не объявляется повреждением.','',
      'Подтверждённые ядра Ж/П/К взяты из ранее вручную проверенных полигонов PR №42, сужены на 3 px; считаются только оставшиеся прозрачные пиксели. Это не оценка всех утраченных пикселей модели и не утверждённый контур новой ткани. Выборочные окна Б/Л требуют художника: разрыв рядом с полой может быть воздухом или дырой. Области В/Н/Р защищают естественное пространство и рваный край, но не объявляют автоматически правильной каждую соседнюю кромку.','',
      'В остаточных ядрах отдельно записаны сохранённый RGB и RGB=0. В последних нет отличимой фактуры; восстановление одной alpha даёт чёрную поверхность. В этом этапе никакая alpha не увеличивалась. Прежние непрозрачные чёрные заполнения main не выдаются за восстановленную авторскую ткань.','',
      'Дополнительно проверены внешние строки/столбцы: в части RAW есть чёрная линия верхней подложки, удаляемая прежней подготовкой, а несколько текущих поз касаются границ холста. Контакт с границей сам по себе не доказывает обрезание тела: это может быть край плаща или мусор у опоры. Точные координаты всех краевых пикселей с alpha ≥128 сохранены в JSON. Ни размеры холста, ни эти кромки здесь не исправлялись.','',
      '**Координаты:** исходный PNG 357×358; (0,0) сверху слева, x вправо, y вниз. Прямоугольники `[x0,y0,x1,y1)` имеют исключённые правую/нижнюю границы. Полигоны в JSON растеризуются Pillow, затем подтверждённые ядра сужаются крестом на 3 px. Каждый `masks/dodge_NN.png` имеет ровно 357×358, совмещается с исходным PNG без масштабирования/сдвига. Прозрачный фон маски означает «вне диагноза», а не «исправно».','',
      '## Сводка','', '| Исходный = игровой | PR №42: все px / RGB донора | Подтверждённый остаток в ядрах | Подозрение в выбранных окнах | Опора |','|---|---:|---:|---:|---|']
    for r in doc['frames']:lines.append(f'| {r["source_frame"]:02d} | {r["previously_repaired_pixels"]} / {r["previous_donor_rgb_pixels"]} | {r["remaining_confirmed_mask_pixels"]} | {r["suspected_mask_pixels"]} | {r["origin"]} |')
    lines+=['','Числа подозрений описывают объём маски осмотра, а не число доказанно потерянных цветовых пикселей. Ноль в подтверждённом ядре не означает, что весь кадр без дефектов.','']
    for r in doc['frames']:
        i=r['source_frame'];lines += [f'## Кадр {i:02d} — исходный {i:02d}, игровой {r["runtime_frame"]:02d}','',
          f'- Оригинал: `{r["source_png"]}`.',f'- До PR №42: `{r["before_png_git"]}`.',f'- Текущий: `{r["current_png"]}`.',f'- Размер: `{r["size"]}`; origin: `{r["origin"]}`; [маска](masks/dodge_{i:02d}.png).',
          f'- Ранее исправлено {r["previously_repaired_pixels"]} px: alpha-only {r["previous_alpha_only_pixels"]}, RGB из соседей {r["previous_donor_rgb_pixels"]}. Точная разница находится в [{r["before_after_page"]}]({r["before_after_page"]}).','',
          '| Участок | Диагноз / уверенность | Координаты | Остаток alpha <128 | RGB оригинала в остатке | Следующий шаг |','|---|---|---|---:|---|---|']
        for reg in r['regions']:
            geometry='полигон '+str(reg['polygon'])+'; сужение 3 px' if 'polygon' in reg else 'окно '+str(reg['inspection_box'])
            next_step='Нужны новые цветовые данные или художественная реставрация.' if reg['category']=='подтверждённый остаток' else reg.get('interpretation','В проверенном ядре остатка не обнаружено; другие области не сертифицированы.')
            lines.append(f'| {reg["id"]} | {reg["category"]}; {reg["confidence"]} | {geometry} | {reg["low_alpha_pixels"]} | нулевой {reg["raw_zero_rgb_pixels"]}; сохранённый {reg["raw_retained_rgb_pixels"]} | {next_step} |')
        lines+=['','**Что изменил PR №42:**']
        trace=r['previous_repairs']
        for entry in trace:
            if not (entry['own_runtime_alpha_pixels'] or entry['donor_rgb_pixels']):continue
            region=entry['region'];title='ближнее бедро/колено' if region.startswith('right_thigh') else 'куртка/корпус' if region.startswith('jerkin') else 'пояс'
            donor=f"донор `{entry['donor_source']}`, смещение {entry['donor_offset']}" if entry.get('donor_source') else 'сохранённый собственный RGB'
            lines.append(f"- {title}: alpha-only {entry['own_runtime_alpha_pixels']}; RGB из соседа {entry['donor_rgb_pixels']}; {donor}.")
        if not trace:lines.append('- Этот кадр PR №42 не менял; прежние улучшения alpha относятся к более ранней подготовке.')
        border=r['border_audit'];contacts='; '.join(k+': '+str(v['count'])+' пикс.' for k,v in border['current_edges'].items() if v['count']) or 'непрозрачных контактов нет'
        lines += ['',f"**Кромки:** в верхней строке RAW {border['source_top_row_black_matte_pixels']} почти чёрных непрозрачных пикс.; текущие кромки — {contacts}. PR №42 кромки не менял. Для контактов проверить мусор/плащ/обрезание по исходнику; диагноз обрезанной части тела не подтверждён.",'', '**Соседние кадры:** для подтверждённых остатков прежний подбор соседей дал только частичное покрытие. Сохранённые доноры/координаты доступны в `assets/combat/restoration/hans/recipe.json`. Полного безопасного восстановления без художественной оценки не подтверждено. Для подозрений сначала утвердить, где должна быть ткань; новые совмещения и переносы здесь не выполнялись.','']
    lines+=['## Движение, повторяемость и ограничения','',
      'Dodge: 12 кадров × 52 ms, примерно 19,2308 FPS; однократное воспроизведение, не ping-pong в текущей main. В атласе ничего не переупорядочено. Видео показывает обе подготовленные версии одновременно: белый и ярко-розовый фоны, ×0,5 и ×1, по два полных Dodge с возвратом в действующий Idle. Производственный контроллер возвращает Idle к ×1; счётчик показывает действительную скорость. Внешний MP4 — обычный H.264/yuv420p, без интерполяции движения.','',
      'Стыки плаща/прорехи меняются между кадрами, особенно 03→04, 05→06 и 09→10. На светлых фонах это читается как мерцание; часть связано с настоящей сменой позы и рваной тканью. Видео оставляет оба типа видимыми. Участки Б/Л нельзя восстанавливать по одному статичному кадру: художник должен проверить весь цикл и не закрыть естественный воздух.','',
      'Фактически выполнен графический запуск официального Godot 4.6.2 (Linux/X11, Mesa llvmpipe), существующая CombatGraphicsLab и production-контроллер. Покадровая фиксация всех 12 пар на трёх фонах; восемь проигрываний Dodge с проверкой посещения всех кадров и возврата обеих моделей в Idle. Это не новое тестирование механик боя или Windows. Точные результаты — `GODOT_CHECK.log`, `MOTION_TIMELINE.json`, `VIDEO_CAPTURE.json`.','',
      'Перед художественной работой утвердить красные и оранжевые области по координатам; запросить неповреждённые исходники для нулевого RGB. После будущей правки повторить то же сравнение на светлых фонах и в движении. Пока ни одна маска не является разрешением на дорисовку.','']
    (OUT/'FRAME_REPORT.md').write_text('\n'.join(lines).rstrip()+'\n')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--captures',type=Path,required=True)
    doc=build(ap.parse_args().captures)
    print(json.dumps({'frames':len(doc['frames']),'confirmed_remaining_pixels':sum(r['remaining_confirmed_mask_pixels'] for r in doc['frames']),'previous_pr42_changed_pixels':sum(r['previously_repaired_pixels'] for r in doc['frames'])},ensure_ascii=False))
