"""Normal main startup, real OS WASD/E/Escape, read-only observer; no time/actor changes."""
import argparse,json,time,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero'];door=start['doors']['herbalist']
w.walk(door['approach'],'shared-home-approach');w.wait(lambda s:s['prompt']=='E — Войти',3);w.capture('shared-home-door');w.pulse(['e'])
w.wait(lambda s:s['active_id']=='herbalist' and not s['busy'] and not s['locked'],8)
w.capture('shared-home-inside')
accepted=False
for attempt in range(4):
 r=w.wait(lambda s:s['residents']['herbalist_brother']['present'] and s['residents']['herbalist_brother']['state']==2,15)['residents']['herbalist_brother']
 pos=r['position']
 try:
  w.walk([pos[0]-24,pos[1]],'brother-conversation-approach')
  w.wait(lambda s:'HerbalistBrother/Interaction' in s['target'],3);accepted=True;break
 except RuntimeError as e:w.log({'action':'moving-target-retry','reason':str(e)})
assert accepted,'Original conversation not reached'
w.pulse(['e']);s=w.wait(lambda s:s['dialogue'] and s['residents']['herbalist_brother']['state']==5,4);pos=s['residents']['herbalist_brother']['position']
w.wait(lambda s:s['residents']['herbalist_brother']['clip'].startswith('talk_'),4);time.sleep(.5)
s=w.state();assert s['residents']['herbalist_brother']['position']==pos
w.capture('brother-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'] and s['residents']['herbalist_brother']['state']!=5,4)
w.log({'action':'brother-native-conversation','success':True,'body':r['body']})
entry=w.state()['entry']
# Approach the exit itself; the spawn point is also within the brother's talk range.
w.walk([entry[0],entry[1]+22],'shared-home-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8);w.capture('shared-home-return')
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
assert final['camera_zoom']==start['camera_zoom'] and math.dist(final['position'],door['approach'])<1
w.log({'action':'brother-native-success','success':True,'hero':hero,'original_ids':ids,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'hero':hero,'original_ids':ids},ensure_ascii=False,indent=2));(out/'STOP').touch()
