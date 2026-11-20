#!/usr/bin/env python3
"""Record the actual existing Godot Lab window; no interpolated video frames."""
import argparse,json,subprocess,time
from pathlib import Path
from PIL import ImageGrab

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--capture-dir',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True);ap.add_argument('--display',default=':95')
    args=ap.parse_args();start=time.monotonic()
    while not (args.capture_dir/'ready').exists():
        if time.monotonic()-start>45:raise RuntimeError('No Godot ready marker')
        time.sleep(.05)
    fps=30
    encoder=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pixel_format','rgb24','-video_size','960x540','-framerate',str(fps),'-i','-','-an','-c:v','libx264','-threads','2','-preset','ultrafast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(args.output)],stdin=subprocess.PIPE)
    began=time.monotonic();count=0;late=0
    try:
        while time.monotonic()-began<45:
            image=ImageGrab.grab(bbox=(20,20,980,560),xdisplay=args.display).convert('RGB')
            encoder.stdin.write(image.tobytes());count+=1
            target=began+count/fps
            if time.monotonic()>target+.025:late+=1
            if (args.capture_dir/'done').exists():break
            time.sleep(max(0,target-time.monotonic()))
    finally:
        encoder.stdin.close();encoder.wait(timeout=20)
    assert encoder.returncode==0 and (args.capture_dir/'done').exists()
    (args.output.parent/'VIDEO_CAPTURE.json').write_text(json.dumps({'capture':'Реальный X11-захват существующей CombatGraphicsLab; старые prepared PNG слева, текущие справа; без вставки промежуточных кадров','fps':fps,'frames':count,'elapsed_seconds':time.monotonic()-began,'late_frames_over_25ms':late,'encoder_exit':encoder.returncode,'window_size':[960,540]},ensure_ascii=False,indent=2)+'\n')
    print('Recorded',count,'frames; late=',late)
if __name__=='__main__':main()
