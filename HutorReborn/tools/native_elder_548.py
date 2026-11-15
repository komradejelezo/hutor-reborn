"""OS-keyboard smoke test of the ordinary main scene. No seek or teleport."""
import argparse,time,json,math
from pathlib import Path
from native_window_playtest import NativeWindow
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=NativeWindow(out)
start=w.state();ids={k:r['body'] for k,r in start['residents'].items()};hero=start['hero'];door=start['doors']['elder']
w.walk(door['approach'],'elder-door');w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='elder' and not s['busy'] and not s['locked'],8);w.capture('elder-inside')
w.walk([432,296],'desk-approach')
w.wait(lambda s:s['residents']['elder']['state']==2 and s['residents']['elder']['position'][0]<480 and s['residents']['elder']['position'][1]<320,65)
w.wait(lambda s:'Elder/Interaction' in s['target'],4);w.pulse(['e'])
s=w.wait(lambda s:s['dialogue'] and s['residents']['elder']['state']==5,4)
pos=s['residents']['elder']['position'];time.sleep(.9);after=w.state()
assert after['residents']['elder']['position']==pos
assert not after['residents']['elder']['clip'].startswith('work_')
w.capture('elder-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'elder-native-dialogue-pauses-resumes','success':True,'body':s['residents']['elder']['body']})
w.walk([560,390],'observe-desk')
w.wait(lambda s:s['residents']['elder']['clip']=='work_write',55);w.capture('elder-writing')
w.walk(w.state()['entry'],'elder-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8);w.capture('elder-return')
assert math.dist(w.state()['position'],door['approach'])<1 and w.state()['camera_zoom']==start['camera_zoom']
w.pulse(['e']);w.wait(lambda s:s['active_id']=='elder' and not s['busy'] and not s['locked'],8)
w.walk(w.state()['entry'],'repeat-elder-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8)
final=w.state();assert final['hero']==hero and {k:r['body'] for k,r in final['residents'].items()}==ids
w.log({'action':'elder-native-success','success':True,'original_ids':ids,'hero':hero,'clock_before':start['clock'],'clock_after':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'final':final,'original_ids':ids,'hero':hero},ensure_ascii=False,indent=2));(out/'STOP').touch()
