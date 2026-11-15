"""Real X11 WASD/E/Escape; existing main scene, no seek/teleport/script fixture."""
import argparse,time,json,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero'];door=start['doors']['inn']
w.walk(door['approach'],'inn-door');w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'],8);w.capture('inn-inside')
w.walk([600,376],'wife-preparation-approach')
# Her real autonomous morning cycle repeatedly reaches the preparation table.
w.wait(lambda s:s['residents']['innkeeper_wife']['state']==2 and s['residents']['innkeeper_wife']['position'][0]<650 and s['residents']['innkeeper_wife']['position'][0]>600,65)
w.wait(lambda s:'InnkeeperWife/Interaction' in s['target'],4);w.pulse(['e'])
s=w.wait(lambda s:s['dialogue'] and s['residents']['innkeeper_wife']['state']==5,4)
pos=s['residents']['innkeeper_wife']['position'];time.sleep(.9);after=w.state()
assert after['residents']['innkeeper_wife']['position']==pos
assert not after['residents']['innkeeper_wife']['clip'].startswith('work_')
w.capture('wife-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'wife-native-dialogue-pauses-resumes','success':True,'body':s['residents']['innkeeper_wife']['body']})
w.walk([580,440],'observe-room')
w.wait(lambda s:s['residents']['innkeeper_wife']['clip'].startswith('carry_') and s['residents']['innkeeper_wife']['state']==1,40)
w.capture('wife-carrying')
w.walk(w.state()['entry'],'inn-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8);w.capture('inn-return')
assert math.dist(w.state()['position'],door['approach'])<1 and w.state()['camera_zoom']==start['camera_zoom']
w.pulse(['e']);w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'],8)
w.walk(w.state()['entry'],'repeat-inn-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8)
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
w.log({'action':'wife-native-success','success':True,'original_ids':ids,'hero':hero,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'original_ids':ids,'hero':hero},ensure_ascii=False,indent=2));(out/'STOP').touch()
