#!/usr/bin/env python3
"""Check decoded MP4 pose coverage using actual Godot still captures."""
from pathlib import Path
import argparse,json,subprocess
import numpy as np
from PIL import Image
D=Path(__file__).resolve().parent
def main(captures):
    refs={}
    for bg in [2,3]:
        image=np.array(Image.open(captures/f'lab-bg{bg}.png').convert('RGB'))
        refs[bg]=np.stack([image[i*170:i*170+150:2,355:490:2] for i in range(5)]).astype(np.int16)
    process=subprocess.Popen(['ffmpeg','-v','error','-i',str(D/'DODGE_05_09_COMPARISON.mp4'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
    seen={2:set(),3:set()};counts={2:0,3:0};index=0
    while True:
        data=process.stdout.read(960*540*3)
        if not data:break
        assert len(data)==960*540*3
        image=np.frombuffer(data,np.uint8).reshape(540,960,3);bg=3 if image[250,500,1]<100 else 2
        roi=image[265:415:2,615:750:2].astype(np.int16)
        mae=np.abs(refs[bg]-roi).mean((1,2,3));best=int(mae.argmin())
        if mae[best]<8:seen[bg].add(best+5);counts[bg]+=1
        index+=1
    process.stdout.close();process.wait(timeout=20)
    assert process.returncode==0 and all(s==set(range(5,10)) for s in seen.values())
    (D/'VIDEO_REVIEW.json').write_text(json.dumps({'decoded_frames':index,'visible_poses':{str(k):sorted(v) for k,v in seen.items()},'matched_video_frames':counts,'method':'Декодированная запись сопоставлена со свежими Godot-снимками пилота. MAE RGB <8/255 на области бойца; H.264 4:2:0 меняет розовые края. Это проверка покрытия позами, не художественное одобрение движения.'},ensure_ascii=False,indent=2)+'\n')
    print('PASS: all five 05-09 poses visible in MP4 on white and pink')
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--captures',type=Path,required=True);main(ap.parse_args().captures)
