#!/usr/bin/env python3
"""Decode the MP4 and verify visible pose coverage against actual Godot stills."""
from pathlib import Path
import json,subprocess
import numpy as np
from PIL import Image
D=Path(__file__).resolve().parent

def main():
    references={}
    for bg,name in [(2,'БЕЛЫЙ'),(3,'РОЗОВЫЙ')]:
        image=np.array(Image.open(D/f'godot/ФОН_{name}.png').convert('RGB'))
        references[bg]=np.stack([image[103+(i//2)*195:253+(i//2)*195:2,365+(i%2)*560:500+(i%2)*560:2] for i in range(12)]).astype(np.int16)
    process=subprocess.Popen(['ffmpeg','-v','error','-i',str(D/'DODGE_COMPARISON.mp4'),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
    seen={2:set(),3:set()};matches={2:0,3:0};errors=[];count=0
    try:
        while True:
            data=process.stdout.read(960*540*3)
            if not data:break
            assert len(data)==960*540*3
            image=np.frombuffer(data,np.uint8).reshape(540,960,3)
            bg=3 if image[250,500,1]<100 else 2
            roi=image[265:415:2,615:750:2].astype(np.int16)
            mae=np.abs(references[bg]-roi).mean((1,2,3));best=int(mae.argmin())
            # Pink background incurs extra chroma error in standard H.264 4:2:0.
            # 8/255 threshold remains well below observed Idle mismatch (>22).
            if mae[best]<8:
                seen[bg].add(best+1);matches[bg]+=1;errors.append(float(mae[best]))
            count+=1
    finally:
        process.stdout.close();process.wait(timeout=20)
    assert process.returncode==0 and all(len(s)==12 for s in seen.values())
    result={'decoded_frames':count,'method':'Декодированный MP4 сопоставлен со статическими кадрами текущей модели Godot; среднее абсолютное отклонение RGB <8/255 на выбранной области бойца. На розовом фоне стандартное сжатие 4:2:0 меняет цвет краёв; точные цвета/маски смотреть в PNG. Это проверка покрытия записи позами, не художественная оценка плавности.','frames_visibly_matched':{str(k):sorted(v) for k,v in seen.items()},'matched_video_frames':matches,'max_matched_mae':max(errors),'all_twelve_poses_on_both_backgrounds':True}
    (D/'VIDEO_REVIEW.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('PASS: decoded MP4 contains all 12 Dodge poses on white and pink; frames:',count)
if __name__=='__main__':main()
