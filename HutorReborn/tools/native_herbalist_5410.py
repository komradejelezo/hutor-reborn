"""Ordinary main scene and real OS WASD/E/Escape, no actor/clock mutation."""
import argparse,json,time,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero']
w.walk([1860,1710],'herbalist-garden-approach')
accepted=False
for i in range(5):
 w.wait(lambda s:s['residents']['herbalist']['present'] and s['residents']['herbalist']['state']==2,45)
 r=w.state()['residents']['herbalist'];pos=r['position']
 try:
  w.walk([pos[0]-24,pos[1]+16],'herbalist-talk-approach')
  w.wait(lambda s:'Herbalist/Interaction' in s['target'],3)
  accepted=True;break
 except RuntimeError as e:w.log({'action':'moving-target-retry','reason':str(e)})
assert accepted,'Could not approach original conversation'
w.pulse(['e']);s=w.wait(lambda s:s['dialogue'] and s['residents']['herbalist']['state']==5,4);pos=s['residents']['herbalist']['position'];time.sleep(2)
s=w.state();assert s['residents']['herbalist']['position']==pos and s['residents']['herbalist']['clip'].startswith('talk_')
w.capture('herbalist-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'herbalist-native-conversation','success':True,'body':r['body']})
w.walk([1860,1710],'observe-herbalist')
w.wait(lambda s:s['residents']['herbalist']['clip']=='gather_herbs',55);w.capture('herbalist-gathering')
w.door('herbalist')
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
assert final['camera_zoom']==start['camera_zoom']
w.log({'action':'herbalist-native-success','success':True,'hero':hero,'original_ids':ids,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'hero':hero,'original_ids':ids},ensure_ascii=False,indent=2));(out/'STOP').touch()
