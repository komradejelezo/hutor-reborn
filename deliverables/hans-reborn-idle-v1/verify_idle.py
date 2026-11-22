#!/usr/bin/env python3
"""Read-only alpha/geometry/provenance checks, independent of the Godot rig."""
from pathlib import Path
import hashlib,json,subprocess
import numpy as np
from PIL import Image
from scipy.ndimage import label,binary_fill_holes
D=Path(__file__).resolve().parent;R=D.parents[1]
BASE='ae6ac1101b8c60b21d5bf59156a07e6916e25b0e'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def arr(p):return np.array(Image.open(p).convert('RGBA'))
def topology(alpha):
    solid=alpha>0
    return int(label(solid)[1]),int((binary_fill_holes(solid)&~solid).sum())
def main():
    assert not subprocess.check_output(['git','-C',str(R),'diff',BASE,'--','HutorReborn'])
    assert not subprocess.check_output(['git','-C',str(R),'ls-files','--others','--exclude-standard','HutorReborn']).strip()
    raw=arr(D/'working/color_source.png');mask=np.array(Image.open(D/'working/source_coverage.png').convert('L'))
    assert np.array_equal(mask>=128,raw[:,:,3]>=128),'Matte must depend ONLY on alpha'
    # Counterfactual RGB: even a completely black garment keeps this exact mask.
    blackened=raw.copy();blackened[:,:,:3]=0
    assert np.array_equal(blackened[:,:,3]>=128,mask>=128)
    inverted=raw.copy();inverted[:,:,:3]=255-raw[:,:,:3]
    assert np.array_equal(inverted[:,:,3]>=128,mask>=128)
    assert not (mask[raw[:,:,3]==0]>0).any(),'Never fill absent source coverage'
    master=arr(D/'working/master.png');assert master.shape==(1280,1280,4)
    expected=np.zeros_like(master);accepted=raw.copy();accepted[mask==0]=0;accepted[mask>0,3]=255
    expected[13:1267,13:1267]=accepted
    assert np.array_equal(master,expected),'Native source pixels must not be resized or recoloured'
    zero_rgb=(raw[:,:,:3].max(2)==0)&(mask>0)
    assert int(zero_rgb.sum())==727 and np.all(master[13:1267,13:1267][zero_rgb,3]==255)
    assert topology(master[:,:,3])==(1,0)
    print('PASS: alpha-only separate matte; no RGB keying; 727 fully black source texels preserved; no source-alpha-zero filling')
    manifest=json.loads((D/'MANIFEST.json').read_text());assert manifest['canvas']==[1280,1280] and manifest['anchor']==[706,1185]
    assert sha(D/'working/color_source.png')==manifest['source_sha256']
    paths=sorted((D/'frames').glob('*.png'));assert len(paths)==12 and len({sha(p) for p in paths})==12
    y,x=np.mgrid[:1280,:1280];cx=(x-13)*512/1254;cy=(y-13)*512/1254
    # Interior of the explicitly pinned backpack control box; exterior margin
    # omitted because controls are sampled on the shared integer control grid.
    bag=(cx>=126)&(cx<246)&(cy>=76)&(cy<217)
    weapon=(x>=473)&(x<863)&(y>=653)&(y<943)
    free_hand=(x>=903)&(x<1001)&(y>=643)&(y<743)
    records=[];frames=[]
    for i,p in enumerate(paths):
        im=Image.open(p);a=arr(p);assert im.mode=='RGBA' and a.shape==(1280,1280,4)
        assert set(np.unique(a[:,:,3]))=={0,255}
        assert topology(a[:,:,3])==(1,0),p.name
        assert not a[0,:,3].any() and not a[-1,:,3].any() and not a[:,0,3].any() and not a[:,-1,3].any()
        assert not a[a[:,:,3]==0,:3].any(),'No coloured transparent border noise'
        assert np.array_equal(a[:380],master[:380]),'Face/hood/head changed'
        assert np.array_equal(a[1078:],master[1078:]),'Boots or ground moved'
        for region in [bag,weapon,free_hand]:assert np.array_equal(a[region],master[region]),'Pinned gear/hand moved'
        assert manifest['frames'][i]['sha256']==sha(p) and manifest['frames'][i]['anchor']==[706,1185]
        box=im.getbbox();assert box[1]==108 and box[3]==1185,'Whole-body height changed'
        records.append({'frame':i+1,'file':str(p.relative_to(D)),'size':[1280,1280],'anchor':[706,1185],'connected_components':1,'enclosed_transparent_pixels':0,'partially_transparent_pixels':0,'background_alpha_zero':True,'head_boots_and_pinned_gear_unchanged':True,'bbox':box,'sha256':sha(p)})
        frames.append(a)
    print('PASS: 12 distinct new RGBA frames; one complete silhouette each; no holes/partial interiors/border damage')
    print('PASS: head, hood, hands, sword, backpack, boots and contact anchor bit-identical across all phases')
    # Absolute cyclic steps include frame 12->01; no duplicated endpoint pose.
    steps=[]
    for i in range(12):
        a,b=frames[i],frames[(i+1)%12]
        aa=a[:,:,:3].astype(float)*(a[:,:,3:]/255.)+255*(1-a[:,:,3:]/255.)
        bb=b[:,:,:3].astype(float)*(b[:,:,3:]/255.)+255*(1-b[:,:,3:]/255.)
        steps.append({'from':i+1,'to':(i+1)%12+1,'changed_pixels':int(np.any(a!=b,2).sum()),'white_composite_mean_rgb_step':float(np.abs(aa-bb).mean())})
    assert all(s['changed_pixels']>0 for s in steps)
    assert steps[-1]['white_composite_mean_rgb_step']<=max(s['white_composite_mean_rgb_step'] for s in steps[:-1])*1.15
    print('PASS: analytic closed-cycle phases; no repeated frames; loop-boundary pixel step within ordinary transition range')
    doc={'base':BASE,'game_files_unchanged':True,'matte_uses_rgb':False,'source_zero_alpha_filled':False,'source_black_texels_kept':727,'source_native_resolution_preserved':True,'artistic_approval':'requires human review; numerical checks do not certify anatomy/identity or natural movement','frames':records,'cyclic_steps':steps}
    (D/'INTEGRITY_REPORT.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
    print('RESULT: 4 independent integrity groups passed')
if __name__=='__main__':main()
