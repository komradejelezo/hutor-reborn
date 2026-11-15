"""Ordinary main scene, real OS WASD/E/Escape; no actor/time mutation."""
import argparse,json,time,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero']
w.walk([670,1050],'crooked-pine-approach')
accepted=False
for i in range(4):
 w.wait(lambda s:s['residents']['old_man']['present'] and s['residents']['old_man']['state']==2,40)
 r=w.state()['residents']['old_man'];pos=r['position']
 try:
  w.walk([pos[0]-24,pos[1]+16],'old-man-talk-approach')
  w.wait(lambda s:'OldMan/Interaction' in s['target'],3)
  accepted=True;break
 except RuntimeError as e:w.log({'action':'moving-target-retry','reason':str(e)})
assert accepted,'Could not approach existing conversation'
w.pulse(['e']);s=w.wait(lambda s:s['dialogue'] and s['residents']['old_man']['state']==5,4);pos=s['residents']['old_man']['position'];time.sleep(3)
s=w.state();assert s['residents']['old_man']['position']==pos and s['residents']['old_man']['clip'].startswith('talk_')
w.capture('old-man-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'old-man-native-conversation','success':True,'body':r['body']})
w.walk([710,1060],'observe-old-man')
w.wait(lambda s:s['residents']['old_man']['clip'] in ['smoke_pipe','sit_smoke'],55);w.capture('old-man-smoking')
door=w.state()['doors']['old_man'];w.walk(door['approach'],'old-man-home-door');w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='old_man' and not s['busy'] and not s['locked'],8);w.capture('old-man-home')
w.walk(w.state()['entry'],'old-man-home-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8)
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
assert final['camera_zoom']==start['camera_zoom'] and math.dist(final['position'],door['approach'])<1
w.log({'action':'old-man-native-success','success':True,'hero':hero,'original_ids':ids,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'hero':hero,'original_ids':ids},ensure_ascii=False,indent=2));(out/'STOP').touch()
