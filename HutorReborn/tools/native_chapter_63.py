#!/usr/bin/env python3
"""Real X11 input; run the ordinary game with the read-only chapter_observer_63 override.

No fixture teleports, clock seeks, quest mutations or injected Godot input.
"""
import argparse
import sys,time,json
from pathlib import Path
from native_chapter_70 import ChapterWindow
class Window(ChapterWindow):
 def route(self,goal):
  pts=super().route(goal)
  if len(pts)<3:return pts
  out=[pts[0]]
  for i in range(1,len(pts)-1):
   a,b,c=pts[i-1:i+2]
   if (b[0]-a[0])*(c[1]-b[1])!=(b[1]-a[1])*(c[0]-b[0]):out.append(b)
  out.append(pts[-1]);return out
parser = argparse.ArgumentParser(); parser.add_argument('--output', type=Path, required=True)
w = Window(parser.parse_args().output.resolve())
w.click('Начать путь'); w.wait(lambda s: s['active'] and not s['busy'], 30)
w.capture('arrival'); w.walk(w.state()['doors']['inn'], 'walk-inn-entrance')
w.pulse(['e']); w.wait(lambda s: s['world']=='inn' and not s['busy'], 20)
w.capture('inn-entry')
def reveal():
 w.wait(lambda s:s['phase']==2,8)
 if w.state()['typing']:w.pulse(['e']);w.wait(lambda s:not s['typing'],8)
def finish():
 for _ in range(5):
  if not w.state()['dialogue']:return
  reveal();w.pulse(['Return'])
 w.wait(lambda s:not s['dialogue'],8)
def answer(text):
 reveal();w.click(text);finish()
def use(target,choice):
 w.wait(lambda s:target.lower() in s['target'].lower(),8);w.pulse(['e']);w.wait(lambda s:s['dialogue'],8);answer(choice)
w.walk([440,216],'wait-near-innkeeper');use('трактирщик','Могу помочь');w.capture('work-offered')
assert w.state()['flags'].get('inn_work')
w.walk([300,404],'dishes-approach');w.capture('dishes-focus');use('грязную посуду','Выполнить действие')
assert w.state()['items'].get('dishes')==1
w.walk([430,280],'counter-approach');use('Отнести посуду','Выполнить действие');assert w.state()['flags'].get('dishes_delivered')
w.capture('dishes-delivered')
# Take up the existing cup task through the real innkeeper conversation.
w.walk([440,216],'return-innkeeper')
use('трактирщик','Чья кружка');assert w.state()['flags'].get('mug_started')
w.walk([510,436],'mug-approach');w.capture('mug-focus');use('забытую кружку','Выполнить действие');assert w.state()['items'].get('mug')==1
w.pulse(['j']);w.wait(lambda s:s['overlay'],8);w.capture('journal');w.click('Закрыть')
w.pulse(['F5']);digest=w.wait(lambda s:bool(s['normal_digest']),8)['normal_digest'];hero=w.state()['hero_id'];w.pulse(['F9']);w.wait(lambda s:s['hero_id']!=hero and not s['busy'],30)
assert w.state()['flags'].get('dishes_delivered') and w.state()['items'].get('mug')==1 and w.state()['normal_digest']==digest
w.capture('save-restored')
(w.output/'result.json').write_text(json.dumps({'success':True,'checks':['normal-new-game','WASD-village-to-inn','real-door','real-innkeeper-work-offer','dishes-pickup-and-counter-E','cup-task-and-pickup-E','journal','F5-F9-progress'],'final':w.state()},ensure_ascii=False,indent=2))
w.log({'action':'native-63-success'})
