#!/usr/bin/env python3
"""Independent byte/pixel provenance and conservation checks for reviewed repairs."""
from pathlib import Path
from io import BytesIO
import json,hashlib,subprocess,sys,copy
import numpy as np
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[1];R=P.parent
sys.path.insert(0,str(P/'tools'))
import restore_hans_combat_frames as restore
BASE='ce7e706'
def git(*args):return subprocess.check_output(['git','-C',str(R),*args])
def polygon(shape,vertices):
    image=Image.new('1',(shape[1],shape[0]));ImageDraw.Draw(image).polygon([tuple(v) for v in vertices],fill=1)
    return np.array(image,bool)
def validate(frame,actual):
    prefix='HutorReborn/assets/combat/forest_v2/'
    before=np.array(Image.open(BytesIO(git('show',BASE+':'+prefix+frame['path']))).convert('RGBA'))
    assert hashlib.sha256(before.tobytes()).hexdigest()==frame['baseline_pixels_sha256']
    raw=np.array(Image.open(restore.PACK/frame['source']).convert('RGBA'));expected=before.copy();corrected=raw.copy()
    allowed=np.zeros(raw.shape[:2],bool);copied=np.zeros_like(allowed)
    for patch in frame['patches']:
        region=polygon(raw.shape[:2],patch['polygon']);allowed|=region
        own=region&(raw[:,:,:3].max(2)>0)
        expected[own,3]=255;corrected[own,3]=255
        if not patch.get('donor_source'):continue
        donor=np.array(Image.open(restore.PACK/patch['donor_source']).convert('RGBA'))
        dx,dy=patch['donor_offset']
        # Independently index the original donor, no image warping/interpolation.
        for y,x in zip(*np.nonzero(region&(raw[:,:,:3].max(2)==0)&(before[:,:,3]<128)&(expected[:,:,:3].max(2)==0))):
            sy,sx=y+dy,x+dx
            if not (0<=sy<donor.shape[0] and 0<=sx<donor.shape[1]):continue
            colour=donor[sy,sx,:3]
            if colour.max()<=8:continue
            expected[y,x,:3]=colour;expected[y,x,3]=255
            corrected[y,x,:3]=colour;corrected[y,x,3]=255;copied[y,x]=True
    assert actual.shape==before.shape and np.array_equal(actual,expected),'Unexpected prepared pixels: '+frame['path']
    assert np.array_equal(actual[~allowed],before[~allowed]),'Outside garment ROI modified'
    assert np.array_equal(actual[-64:],before[-64:]),'Feet/ground pixels changed'
    assert np.all(actual[:,:,3]>=before[:,:,3])
    new_coverage=actual[:,:,3]>before[:,:,3]
    assert not (new_coverage&(actual[:,:,:3].max(2)==0)).any(),'New opaque zero-RGB fill'
    rgb_change=np.any(actual[:,:,:3]!=before[:,:,:3],2)
    assert np.array_equal(rgb_change,copied),'RGB must come from the declared original donor coordinate'
    assert not (rgb_change&(before[:,:,3]>=128)).any(),'Recoloured an existing visible shadow'
    if np.any(actual!=before):
        dest=restore.ROOT/'recovered_source'/Path(frame['source']).relative_to('assets/Hans')
        assert np.array_equal(np.array(Image.open(dest).convert('RGBA')),corrected),'Recovered source mismatch'
    return before,copied

def main():
    recipe=restore.read_recipe();frames=recipe['frames'];changed=0;rgb_pixels=0
    for frame in frames:
        path=restore.PACK/frame['path'];actual=np.array(Image.open(path).convert('RGBA'))
        before,mask=validate(frame,actual);changed+=int(np.any(actual!=before));rgb_pixels+=int(mask.sum())
    assert changed==20 and rgb_pixels==1358,(changed,rgb_pixels)
    print('PASS:',changed,'runtime PNGs; all',rgb_pixels,'new RGB pixels trace to exact adjacent source coordinates')
    print('PASS: source-size/pivot/ground protection; no interpolation, visible-pixel recolour or new opaque black fill')
    for path in ['scripts','scenes','shaders','data','assets/characters','assets/npc','assets/environment','project.godot',
                 'assets/combat/forest_v2/assets','assets/combat/forest_v2/backgrounds','assets/combat/forest_v2/library.json',
                 'assets/combat/forest_v2/prepared/Wolf','assets/combat/forest_v2/prepared/Leshy','assets/combat/forest_v2/prepared/Hans/Idle',
                 'assets/combat/forest_v2/prepared/Hans/Death','assets/combat/forest_v2/prepared/Hans/Use_Invoke']:
        assert not git('diff',BASE,'--','HutorReborn/'+path),path
    assert not git('diff',BASE,'--','HutorReborn/assets/combat/forest_v2/prepared/Hans/frames.tres')
    hashes=json.loads((restore.PACK/'source_checksums.json').read_text())
    for path,digest in hashes.items():assert hashlib.sha256((restore.PACK/path).read_bytes()).hexdigest()==digest,path
    print('PASS: all 259 package originals, approved Idles, other fighters, animation definitions, arena/effects, mechanics/world/NPC/quests/settings unchanged')
    # Negative controls: same validator rejects off-mask edits and black filling.
    frame=next(f for f in frames if np.any(np.array(Image.open(restore.PACK/f['path']))!=restore.baseline(f)))
    actual=np.array(Image.open(restore.PACK/frame['path']).convert('RGBA'))
    bad=actual.copy();bad[0,0]=[12,13,14,255]
    try:validate(frame,bad)
    except AssertionError:pass
    else:raise AssertionError('Off-mask corruption accepted')
    before,mask=validate(frame,actual);y,x=np.argwhere(mask)[0];bad=actual.copy();bad[y,x,:3]=0
    try:validate(frame,bad)
    except AssertionError:pass
    else:raise AssertionError('Black fill accepted')
    invalid=copy.deepcopy(frame);patch=next(p for p in invalid['patches'] if p.get('donor_source'));patch['donor_offset'][0]+=1
    try:restore.restore_frame(invalid)
    except AssertionError:pass
    else:raise AssertionError('Wrong donor registration accepted')
    invalid=copy.deepcopy(frame);invalid['source_sha256']='0'*64
    try:restore.restore_frame(invalid)
    except AssertionError:pass
    else:raise AssertionError('Wrong source hash accepted')
    print('PASS: wrong registration/source hash, off-mask corruption and black fill rejected')
    first={path:value['prepared'].tobytes() for path,value in restore.expected_outputs().items()}
    second={path:value['prepared'].tobytes() for path,value in restore.expected_outputs().items()}
    assert first==second
    print('PASS: read-only reconstruction is deterministic; saved prepared files equal reviewed results')
    print('RESULT: 5 frame-restoration verification groups passed')
if __name__=='__main__':main()
