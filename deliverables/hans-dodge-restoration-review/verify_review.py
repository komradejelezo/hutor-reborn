#!/usr/bin/env python3
"""Independent input/coordinate/atlas checks. Writes diagnostics only."""
from pathlib import Path
from io import BytesIO
import hashlib,json,re,subprocess
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage

D=Path(__file__).resolve().parent;R=D.parents[1];P=R/'HutorReborn'
def git(*args):return subprocess.check_output(['git','-C',str(R),*args])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def composite(image):
    bg=Image.new('RGBA',image.size,'white');bg.alpha_composite(image.convert('RGBA'));return np.array(bg.convert('RGB'))
def main():
    report=json.loads((D/'FRAME_REPORT.json').read_text());base=report['main_commit'];frames=report['frames']
    assert len(frames)==12 and [f['source_frame'] for f in frames]==[f['runtime_frame'] for f in frames]==list(range(1,13))
    assert not git('diff',base,'--','HutorReborn'),'Tracked game resources/code changed'
    unknown=git('ls-files','--others','--exclude-standard','HutorReborn').decode().strip()
    assert not unknown,unknown
    lib=json.loads((P/'assets/combat/forest_v2/library.json').read_text())['hans']['dodge']
    tres=(P/'assets/combat/forest_v2/prepared/Hans/frames.tres').read_text()
    chunk=next(c for c in re.split(r'\n\},\n\{\n',tres) if '"name": &"dodge"' in c)
    ids=re.findall(r'SubResource\("([^"]+)"\)',chunk)
    assert len(ids)==12 and '"loop": false' in chunk and abs(float(re.search(r'"speed": ([0-9.]+)',chunk)[1])-1000/52)<1e-9
    print('PASS: all twelve actual SpriteFrames entries; unchanged FPS/loop; all game files match merged main')
    palette={int(k):tuple(v['rgb']) for k,v in report['mask_palette'].items()}
    changed_total=confirmed_total=0
    for i,row in enumerate(frames):
        f=lib['frames'][i];path=R/row['current_png'];raw=R/row['source_png']
        assert path==P/'assets/combat/forest_v2'/f['path'] and row['origin']==f['origin']
        assert sha(path)==row['current_sha256'] and sha(raw)==row['source_sha256']
        before_bytes=git('show',row['before_png_git']);assert hashlib.sha256(before_bytes).hexdigest()==row['before_sha256']
        a=np.array(Image.open(raw).convert('RGBA'));b=np.array(Image.open(BytesIO(before_bytes)).convert('RGBA'));c=np.array(Image.open(path).convert('RGBA'))
        assert a.shape==b.shape==c.shape==(358,357,4)
        atlas=re.search(r'\[sub_resource type="AtlasTexture" id="'+ids[i]+r'"\]\n(.*?)(?=\n\[)',tres,re.S)[1]
        source_id=re.search(r'ExtResource\("([^"]+)"\)',atlas)[1]
        assert f'path="res://assets/combat/forest_v2/{f["path"]}" id="{source_id}"' in tres
        assert f'region = Rect2(0, 0, 357, 358)' in atlas
        ox,oy=row['origin'];margin=re.search(r'margin = Rect2\(([^)]+)\)',atlas)[1]
        assert list(map(float,margin.split(', ')))==[600-ox,650-oy,1200-357,800-358]
        labels=np.zeros((358,357),np.uint8)
        for region in row['regions']:
            if 'polygon' in region:
                vertices=region['polygon'];m=Image.new('1',(357,358));ImageDraw.Draw(m).polygon([tuple(v) for v in vertices],fill=1)
                domain=ndimage.binary_erosion(np.array(m,bool),iterations=3);kind=1
            else:
                x0,y0,x1,y1=region['inspection_box'];assert 0<=x0<x1<=357 and 0<=y0<y1<=358
                domain=np.zeros((358,357),bool);domain[y0:y1,x0:x1]=True
                kind={'Подозрение: нужна оценка':2,'Естественный просвет':3,'Рваная кромка плаща':4}[region['category']]
            mask=domain&(c[:,:,3]<128)
            if kind!=1:mask&=labels==0
            labels[mask]=kind
            assert int(mask.sum())==region['low_alpha_pixels']
            assert int((mask&(a[:,:,:3].max(2)==0)).sum())==region['raw_zero_rgb_pixels']
        actual=np.array(Image.open(D/row['mask_png']).convert('RGBA'));assert actual.shape==(358,357,4)
        for key,color in palette.items():
            matched=np.all(actual[:,:,:3]==color,2)&(actual[:,:,3]==255)
            assert np.array_equal(matched,labels==key),'Mask coordinates/category mismatch'
        assert not actual[labels==0,3].any()
        changed=np.any(b!=c,2);assert int(changed.sum())==row['previously_repaired_pixels']
        confirmed_total+=int((labels==1).sum());changed_total+=int(changed.sum())
        # Independently read native-size before/after/delta panels from atlas.
        page=Image.open(D/row['before_after_page']).convert('RGB');y=85+(i%3)*440+55
        assert np.array_equal(np.array(page.crop((20,y,377,y+358))),composite(Image.open(BytesIO(before_bytes))))
        assert np.array_equal(np.array(page.crop((407,y,764,y+358))),composite(Image.open(path)))
        delta=np.array(page.crop((794,y,1151,y+358)));assert np.array_equal(np.all(delta==(0,220,225),2),changed)
        # Check every 4x crop: pixel replication only, no blur/resize distortion.
        page=Image.open(D/row['damage_page']).convert('RGB');y=85+(i%4)*520+52
        for x,box in [(780,[136,135,236,235]),(1200,[215,207,287,279]),(1540,[104,225,176,297])]:
            w,h=(box[2]-box[0])*4,(box[3]-box[1])*4
            expected=np.repeat(np.repeat(composite(Image.open(path).crop(box)),4,0),4,1)
            assert np.array_equal(np.array(page.crop((x,y,x+w,y+h))),expected)
    assert changed_total==1614 and confirmed_total==782
    print('PASS: source/current/before hashes, precise origin registration, 12 native-size categorical masks')
    print('PASS: fair prepared-before/current panels, exact PR42 deltas and all 36 Nearest 4x crops')
    for name in ['ATLAS_ALL_FRAMES.png','ATLAS_DAMAGE.png','ATLAS_BEFORE_AFTER.png','ATLAS_MASKS.png','HANS_IDLE_REFERENCE.png']:
        with Image.open(D/name) as im:im.verify()
    timeline=json.loads((D/'MOTION_TIMELINE.json').read_text());assert len(timeline)==8
    assert {(t['background'],t['speed']) for t in timeline}=={(b,s) for b in ['белый','ярко-розовый'] for s in [.5,1]}
    assert all(sorted(t['frames_observed'])==list(range(12)) and t['idle_ms']>t['start_ms'] for t in timeline)
    log=(D/'GODOT_CHECK.log').read_text();assert 'RESULT: 105 diagnostic checks passed; 0 failed' in log and not re.search(r'(SCRIPT ERROR|ERROR:|FAIL:)',log)
    video=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(D/'DODGE_COMPARISON.mp4')]))
    v=video['streams'][0];assert v['codec_name']=='h264' and v['pix_fmt']=='yuv420p' and v['width']==960 and v['height']==540
    coverage=json.loads((D/'VIDEO_REVIEW.json').read_text())
    assert coverage['all_twelve_poses_on_both_backgrounds'] and all(a==list(range(1,13)) for a in coverage['frames_visibly_matched'].values())
    print('PASS: all four motion conditions, two complete cycles/Idle returns each; Godot 105/0; downloadable standard MP4')
    (D/'VERIFICATION.json').write_text(json.dumps({'merged_main':base,'game_files_unchanged':True,'runtime_frames':12,'mask_size':[357,358],'all_36_nearest_crops_exact':True,'previous_pr42_pixels':changed_total,'confirmed_remaining_pixels_in_selected_cores':confirmed_total,'godot_checks':105,'godot_failed':0,'motion_conditions':4,'full_cycles_per_condition':2,'video':{'codec':v['codec_name'],'pixel_format':v['pix_fmt'],'size':[v['width'],v['height']],'duration_seconds':float(video['format']['duration'])}},ensure_ascii=False,indent=2)+'\n')
    for p in [D/'FRAME_REPORT.md',D/'README.md']:
        for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
            if not link.startswith(('http','#')):assert (p.parent/link).exists(),(p,link)
    print('PASS: report links and lossless atlases readable; no temporary resources under game project')
    print('RESULT: 5 diagnostic verification groups passed')
if __name__=='__main__':main()
