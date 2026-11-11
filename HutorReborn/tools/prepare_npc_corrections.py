"""Stage 5.4.1 technical re-crops. Never redraw or stretch anatomy.
Keeps every Stage54 input unchanged; only known clipped work bounds are expanded.
Pillow/numpy/scipy authoring dependencies are the same as Stage54.
"""
from pathlib import Path
import ast,json,hashlib
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1]
OLD=P/'assets/npc/stage54';OUT=P/'assets/npc/stage541';OUT.mkdir(exist_ok=True)
# Load only pure alpha helpers: importing the old authoring script would rewrite its inputs.
ns={}
for node in ast.parse((P/'tools/prepare_npc_rework.py').read_text()).body:
    if isinstance(node,(ast.Import,ast.ImportFrom,ast.FunctionDef)):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'stage54-alpha','exec'),ns)
extract=ns['extract']
FIX={
 'woodcutter':{'work_chop':(632,774),'work_saw':(796,927)},
 'herbalist_brother':{'work_chop':(616,761)},
 'herbalist':{'work_dry':(832,973)},
 'innkeeper':{'work_tray':(841,966)},
 'innkeeper_wife':{'work_tray':(841,970)},
}
m=json.loads((OLD/'manifest.json').read_text());manifest={'base':'a4fccc2','artistic_redesign_complete':False,'changes':[]}
for id,r in m['residents'].items():
    folder=OUT/id;folder.mkdir(exist_ok=True)
    atlas=Image.open(OLD/'game'/id/'atlas.png').convert('RGBA')
    source=Image.open(P/r['reference']).convert('RGBA')
    altered=False
    for f in r['frames']:
        name=f['clip']
        if name not in FIX.get(id,{}):continue
        image=source.copy()
        if id=='herbalist_brother':
            # Caption occupies only first two cells; raised axe in cell 3 is untouched.
            ImageDraw.Draw(image).rectangle((342,616,533,656),fill=(0,0,0,255))
        if id=='herbalist' and name=='work_dry':
            ImageDraw.Draw(image).rectangle((941,832,1004,834),fill=(0,0,0,255))
        box=f['box'];new=[box[0],FIX[id][name][0],box[2],FIX[id][name][1]]
        crop=extract(image,new)
        # Same uniform source-to-game ratio and old world pivot. No recentering on axe/tool.
        ratio=f['scale'];x=f['offset'][0];y=f['offset'][1]-(box[1]-new[1])*ratio
        cell=crop.transform((96,96),Image.Transform.AFFINE,(1/ratio,0,-x/ratio,0,1/ratio,-y/ratio),resample=Image.Resampling.NEAREST)
        index=r['clips'][name][f['index']];atlas.paste(cell,(index%8*96,index//8*96));altered=True
        manifest['changes'].append({'id':id,'clip':name,'frame':f['index'],'before':box,'after':new,'scale':ratio,'pivot':[48,82],'texture_index':index,'reference_sha256':r['sha256']})
    text=(OLD/'game'/id/'frames.tres').read_text()
    if altered:
        atlas.save(folder/'atlas.png')
        text=text.replace('res://assets/npc/stage54/game/'+id+'/atlas.png','res://assets/npc/stage541/'+id+'/atlas.png')
    text=text.replace('metadata/rework_version = 54','metadata/rework_version = 54\nmetadata/correction_version = 541')
    (folder/'frames.tres').write_text(text)
(OUT/'corrections.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Re-cropped',len(manifest['changes']),'frames; anatomy and gait phases remain subject to artist review.')
