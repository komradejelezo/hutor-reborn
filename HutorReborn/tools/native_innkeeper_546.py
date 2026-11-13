"""OS-keyboard innkeeper playtest; launch native_window_playtest.py first."""
import argparse,time,json,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero'];door=start['doors']['inn']
w.walk(door['approach'],'inn-door');w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'],8);w.capture('inn-inside')
assert all(abs(x-1.3)<.001 for x in w.state()['camera_zoom'])
w.walk([470,330],'counter-guest-side')
w.wait(lambda s:s['residents']['innkeeper']['state']==2 and s['residents']['innkeeper']['position'][0]<550 and s['residents']['innkeeper']['position'][1]<245,55)
r=w.state()['residents']['innkeeper'];w.walk([r['position'][0],r['position'][1]+90],'counter-talk-approach')
w.wait(lambda s:'Innkeeper/Interaction' in s['target'],3);w.pulse(['e'])
s=w.wait(lambda s:s['dialogue'] and s['residents']['innkeeper']['state']==5,4);position=s['residents']['innkeeper']['position'];time.sleep(.8)
assert w.state()['residents']['innkeeper']['position']==position and not w.state()['residents']['innkeeper']['clip'].startswith('work_')
w.capture('counter-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'counter-dialogue-stop-resume','success':True,'body':r['body']})
w.walk([660,310],'hearth-observation')
w.wait(lambda s:s['residents']['innkeeper']['clip']=='work_cook',60);w.capture('hearth-work')
r=w.state()['residents']['innkeeper']
try:w.walk([r['position'][0],r['position'][1]+24],'hearth-talk-approach')
except RuntimeError as e:
 w.log({'action':'moving-target-approach-retry','reason':str(e)})
w.wait(lambda s:'Innkeeper/Interaction' in s['target'],3);w.pulse(['e'])
w.wait(lambda s:s['dialogue'] and s['residents']['innkeeper']['state']==5,4);w.capture('hearth-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'hearth-dialogue-stop-resume','success':True})
w.walk(w.state()['entry'],'inn-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8);w.capture('inn-return')
assert math.dist(w.state()['position'],door['approach'])<1 and w.state()['camera_zoom']==start['camera_zoom']
w.pulse(['e']);w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'],8)
w.walk(w.state()['entry'],'inn-repeat-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e']);w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8)
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
w.log({'action':'innkeeper-native-success','original_ids':ids,'hero':hero,'success':True,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'original_ids':ids,'hero':hero},ensure_ascii=False,indent=2));(out/'STOP').touch()
