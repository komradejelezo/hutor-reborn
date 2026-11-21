#!/usr/bin/env python3
"""Independent conservation/alpha/topology/protected-pixel checks for pilot."""
from pathlib import Path
import hashlib,json,re,subprocess
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes,label
D=Path(__file__).resolve().parent;R=D.parents[1]
def git(*args):return subprocess.check_output(['git','-C',str(R),*args])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    config=json.loads((D/'CURATION.json').read_text());result=[]
    assert not git('diff',config['base'],'--','HutorReborn')
    assert not git('ls-files','--others','--exclude-standard','HutorReborn').strip()
    print('PASS: all game files match main after PR43; no new game resources')
    for row in config['frames']:
        n=row['frame'];name=f'dodge_{n:02d}.png'
        assert (D/'before'/name).read_bytes()==(R/row['source']).read_bytes()
        assert sha(R/row['source'])==row['source_sha256'] and sha(D/'restored'/name)==row['restored_sha256']
        original=Image.open(D/'before'/name);image=Image.open(D/'restored'/name)
        assert original.mode==image.mode=='RGBA' and original.size==image.size==(357,358)
        a=np.array(original);b=np.array(image);patch=np.array(Image.open(D/'patches'/name).convert('RGBA'))
        mask=patch[:,:,3]>0;expected=a.copy();expected[mask]=patch[mask]
        assert np.array_equal(b,expected) and np.array_equal(mask,np.any(a!=b,2))
        assert int(mask.sum())==row['edited_pixels'] and np.all(b[:,:,3]>=a[:,:,3])
        assert np.all(b[mask,3]==255) and np.all(b[mask,:3].max(1)>8) and np.all(b[mask,:3].max(1)<180)
        assert len(np.unique(b[mask,:3],axis=0))==row['unique_new_rgb'] and row['unique_new_rgb']>30
        assert original.getchannel('A').getbbox()==image.getchannel('A').getbbox()
        assert np.array_equal(a[:145],b[:145]) and np.array_equal(a[260:],b[260:]),'Head, backpack, feet and ground strips unchanged'
        healthy=(a[:,:,3]>=128)&(a[:,:,:3].max(2)>0)
        assert np.array_equal(a[healthy],b[healthy]),'Valid opaque/semiopaque colour was repainted'
        review=np.array(Image.open(R/f'deliverables/hans-dodge-restoration-review/masks/{name}').convert('RGBA'))
        protected=(review[:,:,3]>0)&~np.all(review[:,:,:3]==[220,35,55],2)
        assert np.array_equal(a[protected],b[protected]),'Natural air, torn cloak edge or pending region changed'
        solid0=a[:,:,3]>=128;solid1=b[:,:,3]>=128
        holes0=binary_fill_holes(solid0)&~solid0;holes1=binary_fill_holes(solid1)&~solid1
        assert not (holes1&~holes0).any(),'New enclosed transparent opening'
        ids0,n0=label(holes0);ids1,n1=label(holes1)
        assert n1<=n0,'More enclosed components than before'
        for component in range(1,n0+1):
            assert len(set(ids1[ids0==component])-{0})<=1,'A remaining old hole was fragmented into new islands'
        raw=np.array(Image.open(R/f'HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/{name}').convert('RGBA'))
        retextured=mask&(a[:,:,3]>=128)
        assert np.all(a[retextured,:3]==0) and np.all(raw[retextured,:3]==0) and np.all(raw[retextured,3]<128)
        result.append({'frame':n,'size':[357,358],'edited_pixels':int(mask.sum()),'new_colour_variants':row['unique_new_rgb'],'new_transparent_pixels':0,'new_enclosed_gap_pixels':0,'enclosed_components_before':n0,'enclosed_components_after':n1,'fragmented_old_gaps':0,'protected_pixels_changed':0,'healthy_visible_rgb_changed':0,'new_opaque_black_pixels':0,'before_confirmed_remaining':row['prior_confirmed_before'],'after_confirmed_remaining':row['prior_confirmed_remaining']})
    assert sum(x['edited_pixels'] for x in result)==410
    print('PASS: all three 357x358 RGBA PNGs and saved baselines; exact frozen texture patches only')
    print('PASS: all valid body/gear pixels, feet, source bounds, natural gaps and ragged cloak edges unchanged')
    print('PASS: no alpha loss, new enclosed gaps, newly transparent pixels or flat black fill')
    lib=json.loads((R/'HutorReborn/assets/combat/forest_v2/library.json').read_text())['hans']['dodge']
    assert lib['ms']==52 and len(lib['frames'])==12
    assert all(lib['frames'][n-1]['size']==[357,358] and lib['frames'][n-1]['origin']==[172.5,351] for n in [5,6,7,8,9])
    log=(D/'GODOT_CHECK.log').read_text();assert 'RESULT: 76 pilot display checks passed; 0 failed' in log
    for row in config['frames']:assert f'PILOT_INPUT_{row["frame"]}: {row["restored_sha256"]}' in log,'Godot capture used a different pilot PNG'
    assert not re.search(r'SCRIPT ERROR|ERROR:|FAIL:',log)
    timeline=json.loads((D/'MOTION_TIMELINE.json').read_text());assert len(timeline)==8
    assert {(t['background'],t['speed']) for t in timeline}=={(b,r) for b in [2,3] for r in [.5,1]}
    assert all(sorted(t['frames_observed'])==list(range(12)) for t in timeline)
    print('PASS: original 52ms/FPS/registration; Godot 76/0; all 05-09 transitions visited at both speeds/backgrounds')
    for name in ['ATLAS_WHITE_PINK.png','ACCEPTED_REGIONS.png','godot/GODOT_SEQUENCE.png']:
        with Image.open(D/name) as im:im.verify()
    for row in result:
        with Image.open(D/f'comparisons/FRAME_{row["frame"]:02d}_BEFORE_AFTER.png') as im:im.verify()
    (D/'CHECKS.json').write_text(json.dumps({'base':config['base'],'game_files_unchanged':True,'artist_approval':False,'full_restoration_complete':False,'frames':result,'godot_passed':76,'godot_failed':0},ensure_ascii=False,indent=2)+'\n')
    print('RESULT: 5 pilot verification groups passed; full artistic restoration remains incomplete')
if __name__=='__main__':main()
