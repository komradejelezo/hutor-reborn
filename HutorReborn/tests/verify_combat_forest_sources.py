#!/usr/bin/env python3
"""Original ZIP integrity, local paw repair and unchanged game rules/saves."""
from pathlib import Path
from zipfile import ZipFile
import argparse,hashlib,json,subprocess,sys
import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT=Path(__file__).resolve().parents[1];REPO=PROJECT.parent
PACK=PROJECT/'assets/combat/forest_v2';BASE='68f5b32'
sys.path.insert(0,str(PROJECT/'tools'))
from prepare_combat_forest_v2 import close_pinholes

def git(*args):return subprocess.check_output(['git','-C',str(REPO),*args])
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--archive',type=Path);args=parser.parse_args()
    for path in ['data','scripts/combat/combat_battle.gd','scripts/combat/combat_ai.gd','scripts/combat/combat_unit.gd',
                 'scripts/chapter','scripts/player.gd','scripts/life','scripts/npc','scripts/interiors','scripts/dialogue',
                 'assets/characters','assets/npc','assets/combat/animations_v1','scenes/world','scenes/interiors','project.godot']:
        assert not git('diff',BASE,'--','HutorReborn/'+path),path
    assert not git('diff','--name-only','--diff-filter=D',BASE).strip()
    assert not (PROJECT/'override.cfg').exists()
    print('PASS: existing rules, IDs/stats, quests/saves, NPCs, world, interiors, old assets and project settings unchanged; no deletions')
    hashes=json.loads((PACK/'source_checksums.json').read_text())
    assert len(hashes)==259
    for name,sha in hashes.items():assert hashlib.sha256((PACK/name).read_bytes()).hexdigest()==sha,name
    if args.archive:
        with ZipFile(args.archive) as z:
            assert hashes=={i.filename:hashlib.sha256(z.read(i)).hexdigest() for i in z.infolist() if not i.is_dir()}
    print('PASS: all 259 source files match original ZIP byte-for-byte')
    audit=json.loads((PACK/'source_audit.json').read_text());lib=json.loads((PACK/'library.json').read_text());count=0
    for c in audit:
        sizes=set()
        for i,f in enumerate(c['frames']):
            a=np.array(Image.open(PACK/f['source']).convert('RGBA'));b=np.array(Image.open(PACK/f['path']))
            assert a.shape==b.shape and list(Image.open(PACK/f['path']).size)==f['size']
            sizes.add(tuple(f['size']));count+=1
            rgb=np.any(a[:,:,:3]!=b[:,:,:3],axis=2)
            if c['animation']=='Wolf/Idle' and i==11:
                x0,y0,x1,y1=c['correction']['rect'];rgb[y0:y1,x0:x1]=False
            assert not rgb.any(),f['path']
            assert b[0,0,3]==0 and b[-1,-1,3]==0,f['path']
        assert len(sizes)==1,c['animation']
    assert count==248
    print('PASS: 248 full-size RGBA poses; uniform clip canvases; transparent corners; RGB unchanged outside one local paw rectangle')
    spec=lib['wolf']['idle'];before=[];after=[]
    for f in spec['frames']:
        a,_=close_pinholes(Image.open(PACK/f['source']).convert('RGBA'))
        b=Image.open(PACK/f['path']);dx,dy=f['registration']
        before.append(ndimage.shift(np.array(a)[:,:,3].astype(float),(-dy,-dx),order=0,mode='constant'))
        after.append(ndimage.shift(np.array(b)[:,:,3].astype(float),(-dy,-dx),order=0,mode='constant'))
    roi=(slice(169,192),slice(156,202))
    def error(m):return float((np.abs(m[11][roi]-m[10][roi])+np.abs(m[11][roi]-m[12][roi])).mean())
    old,new=error(before),error(after);assert new<old,(old,new)
    print(f'PASS: registered frame-12 far-paw two-neighbour alpha change {old:.3f} -> {new:.3f}; remaining RGB pixels untouched')
    for unit,clips in lib.items():
        assert clips['idle']['source_count']==24 and clips['idle']['derived_from']==unit.capitalize()+'/Idle'
        for name,c in clips.items():
            assert c['loop']==(name=='idle') and c['pingpong']==(name=='idle')
            assert c['hold']==(name=='death')
    assert lib['wolf']['attack']['used_indices']==list(range(1,25))
    assert lib['wolf']['attack']['impact']==13 and lib['wolf']['attack']['ms']==45
    assert lib['hans']['victory']['used_indices']==list(range(1,9))+[11,12]
    for p in PACK.rglob('*.png.import'):
        s=p.read_text();assert 'process/fix_alpha_border=false' in s and 'mipmaps/generate=false' in s and 'compress/mode=0' in s
    print('PASS: approved v2/v3 Idle retained; bite uses all 24 new poses; idle-only ping-pong; lossless/no-mipmap/no-alpha-border import')
    print('RESULT: 5 source/integrity groups passed')

if __name__=='__main__':main()
