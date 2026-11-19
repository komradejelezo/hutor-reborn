#!/usr/bin/env python3
"""Check coverage restoration against main, without changing approved RGB/poses."""
from pathlib import Path
from io import BytesIO
import json,subprocess,sys
import numpy as np
from PIL import Image
from scipy import ndimage

P=Path(__file__).resolve().parents[1];R=P.parent;BASE='6dbba6a'
def git(*args):return subprocess.check_output(['git','-C',str(R),*args])
def main():
    for path in ['data','scripts/combat/combat_battle.gd','scripts/combat/combat_ai.gd','scripts/combat/combat_unit.gd',
                 'assets/characters','assets/npc','assets/combat/stage61/source','assets/combat/forest_v2/assets','assets/combat/forest_v2/backgrounds',
                 'scripts/player.gd','scripts/chapter','scripts/npc','scripts/life','scripts/interiors','scripts/dialogue','scenes/world','scenes/interiors','project.godot']:
        assert not git('diff',BASE,'--','HutorReborn/'+path),path
    assert not git('diff','--name-only','--diff-filter=D',BASE).strip()
    print('PASS: approved originals/world/NPCs/portraits, rules, IDs/stats, quests, saves and project settings unchanged')
    audit=json.loads((P/'assets/combat/readability/opacity_audit.json').read_text());restored=0;count=0
    for row in audit:
        path=P/row['path'];original=row.get('original',row['path'])
        source_image=Image.open(BytesIO(git('show',BASE+':HutorReborn/'+original))).convert('RGBA')
        a=np.array(source_image)
        if row.get('source_box'):
            sys.path.insert(0,str(P/'tools'))
            from repair_combat_opacity import native_body
            raw=native_body(source_image.crop(row['source_box']));body=raw.crop(raw.getbbox())
            scaled=body.resize((round(body.width*row['uniform_scale']),174),Image.Resampling.NEAREST)
            cell=Image.new('RGBA',(288,288));cell.paste(scaled,(144-scaled.width//2,72));a=np.array(cell)
        b=np.array(Image.open(path).convert('RGBA'))
        if row.get('source_sampling_factor',1)>1:
            factor=row['source_sampling_factor'];folder='herbalist5410' if 'herbalist' in row['path'] else 'woodcutter542'
            manifest=json.loads((P/'assets/npc'/folder/'manifest.json').read_text())
            rebuilt=Image.new('RGBA',(a.shape[1]*factor,a.shape[0]*factor))
            for i,rec in enumerate(manifest['frames']):
                raw=Image.open(P/'assets/npc'/folder/'source'/rec['source']).convert('RGBA').crop(rec['box'])
                ratio=rec['scale_uniform']*factor;ox,oy=[v*factor for v in rec['offset']]
                cell=raw.transform((96*factor,96*factor),Image.Transform.AFFINE,(1/ratio,0,-ox/ratio,0,1/ratio,-oy/ratio),resample=Image.Resampling.NEAREST)
                rebuilt.paste(cell,(i%8*96*factor,i//8*96*factor))
            a=np.array(rebuilt)
        assert a.shape==b.shape,path
        assert np.array_equal(a[:,:,:3],b[:,:,:3]),path
        if row.get('source_sampling_factor',1)==1:
            assert np.all(b[:,:,3]>=a[:,:,3]),path
        else:
            # Direction captions/faint sheet backdrop are not body coverage.
            assert not b[250:288,:,3].any(),"source direction caption must not enter the first combat frame"
        assert row.get('core_nonopaque',0)==0
        if row.get('reason'):assert np.array_equal(a,b),path
        restored+=int((a[:,:,3]!=b[:,:,3]).sum());count+=1
    assert count==252 and restored>0
    print('PASS:',count,'textures; RGB traceable to approved sources; body coverage restored; herbalist sheet captions/backdrop removed;',restored,'alpha pixels corrected')
    for name in ['herbalist','woodcutter']:
        text=(P/'assets/combat/readability'/f'{name}_frames.tres').read_text()
        folder='herbalist5410' if name=='herbalist' else 'woodcutter542'
        old=(P/'assets/npc'/folder/'game/frames.tres').read_text()
        text=text.replace('res://assets/combat/readability/'+name+'_atlas.png','res://assets/npc/'+folder+'/game/atlas.png')
        if name in ['herbalist','woodcutter']:
            import re
            text=re.sub(r'region = Rect2\((\d+), (\d+), 288, 288\)',lambda m:f'region = Rect2({int(m[1])//3}, {int(m[2])//3}, 96, 96)',text)
        assert text==old
    for path in ['assets/combat/forest_v2/library.json','assets/combat/forest_v2/prepared/Hans/frames.tres','assets/combat/forest_v2/prepared/Wolf/frames.tres','assets/combat/forest_v2/prepared/Leshy/frames.tres']:
        assert not git('diff',BASE,'--','HutorReborn/'+path),path
    print('PASS: approved frame selection/order, timing, pivots, source ratios and local wolf paw correction preserved')
    for folder in ['assets/combat/forest_v2/prepared','assets/combat/readability']:
        for p in (P/folder).rglob('*.png.import'):
            t=p.read_text();assert 'process/premult_alpha=false' in t and 'process/fix_alpha_border=false' in t and 'mipmaps/generate=false' in t
    shader=(P/'shaders/combat_readable.gdshader').read_text()
    assert 'blend_mix' in shader and 'vec4(rgb,c.a)*actor_tint' in shader and 'c.a=1' not in shader
    assert 'TIME' not in (P/'shaders/combat_field_shade.gdshader').read_text()
    print('PASS: straight-alpha import/mix, no forced rectangular alpha or animated background distortion')
    print('RESULT: 4 opacity/source groups passed')

if __name__=='__main__':main()
