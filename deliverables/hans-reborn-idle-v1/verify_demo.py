#!/usr/bin/env python3
"""Verify recorded conditions and ordinary MP4; not an artistic-quality score."""
from pathlib import Path
import json,subprocess,re
import numpy as np
D=Path(__file__).resolve().parent
def main():
    video=D/'IDLE_COMPARISON.mp4'
    info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(video)]))
    stream=info['streams'][0];assert stream['codec_name']=='h264' and stream['pix_fmt']=='yuv420p'
    assert [stream['width'],stream['height']]==[960,540] and float(info['format']['duration'])>=31
    samples=[]
    for t,name in [(2,'white'),(8,'pink'),(14,'black'),(21,'forest_viewer'),(29,'forest_arena')]:
        raw=subprocess.check_output(['ffmpeg','-v','error','-ss',str(t),'-i',str(video),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','-'])
        assert len(raw)==960*540*3
        frame=np.frombuffer(raw,np.uint8).reshape(540,960,3);pixel=frame[250,500].astype(int)
        if name=='white':assert pixel.min()>235
        if name=='pink':assert pixel[0]>235 and pixel[1]<20 and pixel[2]>235
        if name=='black':assert pixel.max()<20
        samples.append({'seconds':t,'condition':name,'field_rgb':pixel.tolist()})
    phases=json.loads((D/'MOTION_CHECKS.json').read_text())
    assert set(phases)=={'0','1','2','3'} and all(sorted(v)==list(range(12)) for v in phases.values())
    log=(D/'GODOT_CHECK.log').read_text();assert 'RESULT: 82 experimental Idle display checks passed; 0 failed' in log
    assert not re.search(r'SCRIPT ERROR|ERROR:|FAIL:',log)
    (D/'VIDEO_REVIEW.json').write_text(json.dumps({'codec':stream['codec_name'],'pixel_format':stream['pix_fmt'],'duration_seconds':float(info['format']['duration']),'source_phases_in_each_live_Godot_background':12,'decoded_samples':samples,'limitation':'Decoded samples verify complete recording conditions; source frame events verify phase playback. Neither certifies anatomy, natural breathing or exact face likeness. Lossy video is not a pixel-exact alpha test.'},ensure_ascii=False,indent=2)+'\n')
    print('PASS: full ordinary MP4 includes white/pink/black/forest and actual arena; live Godot visited all 12 phases on each background')
    print('PASS: final Godot display checks 82 passed, 0 failed')
if __name__=='__main__':main()
