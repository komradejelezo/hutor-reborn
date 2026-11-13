import sys,time,math,json,argparse
from pathlib import Path
from native_window_playtest import NativeWindow
parser=argparse.ArgumentParser(description='OS keyboard playtest of the original boy; first launch native_window_playtest.py in another terminal.')
parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
out=args.output.resolve();w=NativeWindow(out)
ids={k:r['body'] for k,r in w.state()['residents'].items()};hero=w.state()['hero'];door=w.state()['doors']['woodcutter']
w.walk(door['approach'],'family-door');w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='woodcutter' and not s['busy'] and not s['locked'],8);w.capture('family-home')
selected=False
for attempt in range(7):
 s=w.state();r=s['residents']['woodcutter_son'];goal=[r['position'][0],r['position'][1]+23]
 try:w.walk(goal,'approach-son')
 except RuntimeError as e:
  w.log({'action':'moving-target-approach-retry','reason':str(e)})
 s=w.state()
 if 'WoodcutterSon' in s['target']:
  selected=True;break
assert selected, 'Original son could not be selected via E'
w.pulse(['e']);talk=w.wait(lambda s:s['dialogue'] and s['residents']['woodcutter_son']['state']==5,4)
w.capture('son-dialogue');p=talk['residents']['woodcutter_son']['position'];time.sleep(.6)
assert w.state()['residents']['woodcutter_son']['position']==p
w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'],4)
w.log({'action':'original-son-dialogue-stop-resume','body':talk['residents']['woodcutter_son']['body'],'success':True})
w.walk(w.state()['entry'],'home-exit');w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'],8)
w.walk([1720,950],'yard-observation')
w.pulse(['F7']);w.wait(lambda s:s['clock']>=485,15);w.pulse(['F7']);w.pulse(['F7'])
w.wait(lambda s:s['residents']['woodcutter_son']['present'],10)
w.capture('son-yard');clips=set();began=time.monotonic()
while time.monotonic()-began<24:
 clips.add(w.state()['residents']['woodcutter_son']['clip']);time.sleep(.05)
w.log({'action':'normal-yard-play','clips':sorted(clips),'success':True})
w.pulse(['F7']);w.wait(lambda s:s['clock']>=1085,40)
w.wait(lambda s:s['residents']['woodcutter_son']['scene']=='woodcutter',12);w.pulse(['F7']);w.pulse(['F7'])
final=w.state();assert {k:r['body'] for k,r in final['residents'].items()}==ids and final['hero']==hero
w.log({'action':'son-evening-home-return','success':True,'record':final['residents']['woodcutter_son'],'clock':final['clock']})
(out/'result.json').write_text(json.dumps({'success':True,'original_bodies':ids,'hero':hero,'yard_clips':sorted(clips),'final':final},ensure_ascii=False,indent=2))
w.capture('evening-yard');(out/'STOP').touch()
