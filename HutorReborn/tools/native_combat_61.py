"""Real X11 mouse control; observations never modify battle/NPC state."""
import argparse,ctypes as C,json,time
from pathlib import Path
from native_window_playtest import NativeWindow
class CombatWindow(NativeWindow):
 def click(self, label=None,unit=None):
  def find(s):
   return next((b for b in s['buttons'] if not b['disabled'] and ((unit is not None and b['unit']==unit) or (label is not None and b['text'].startswith(label)))),None)
  s=self.wait(lambda s:find(s) is not None,6);b=find(s);x,y=b['center'];old_actions=s.get('arena',{}).get('actions',0)
  self.xt.XTestFakeMotionEvent.argtypes=[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]
  self.xt.XTestFakeButtonEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
  self.xt.XTestFakeMotionEvent(self.display,-1,20+int(x),20+int(y),0);self.x.XFlush(self.display);time.sleep(.03)
  self.xt.XTestFakeButtonEvent(self.display,1,1,0);self.x.XFlush(self.display);time.sleep(.05)
  self.xt.XTestFakeButtonEvent(self.display,1,0,0);self.x.XFlush(self.display)
  released_tick=self.state()['tick']
  self.wait(lambda n:n['tick']>released_tick+2,5)
  if unit is not None or label in ['Защита','Уйти']:
   self.wait(lambda n:n.get('arena',{}).get('actions',0)>old_actions or n.get('arena',{}).get('result'),5)
  self.log({'action':'mouse','label':label,'unit':unit,'center':b['center']})
 def player(self):return self.wait(lambda s:'arena' in s and not s['arena']['busy'],12)
 def picker(self):
  self.click('Другой сценарий' if self.state().get('arena',{}).get('result') else 'Сценарии');self.wait(lambda s:s.get('arena',{}).get('picker'),4)
 def scenario(self,name,id):
  self.click(name);self.wait(lambda s:s.get('arena',{}).get('scenario')==id,4);return self.player()
 def finish(self,defend=False):
  for _ in range(120):
   s=self.player();a=s['arena']
   if a['result']:return a['result']
   if defend:self.click('Защита');continue
   allies=[(k,u) for k,u in a['units'].items() if u['team']==0 and u['hp']>0];allies.sort(key=lambda kv:kv[1]['hp']/kv[1]['max_hp'])
   hurt=allies[0][1];target=allies[0][0]
   heal=next((b for b in s['buttons'] if b['text'].startswith('Лечение') and not b['disabled']),None)
   if heal and hurt['max_hp']-hurt['hp']>=25:self.click('Лечение');self.click(unit=target)
   elif a['potions'] and hurt['hp']<hurt['max_hp']*.42:self.click('Настойка');self.click(unit=target)
   else:
    self.click('Атака');s=self.state()
    if s['arena']['result']:return s['arena']['result']
    if s['arena']['busy']:continue
    targets=[b for b in s['buttons'] if b['unit'] and not b['disabled']]
    if not targets:self.click('Защита')
    else:self.click(unit=targets[0]['unit'])
  raise RuntimeError('Native fight did not end')
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();w=CombatWindow(out)
 w.capture('main-menu');w.click('Испытание боем');w.wait(lambda s:s.get('arena',{}).get('picker'),5);w.capture('scenarios')
 w.scenario('Один на один','duel');w.click('Анимации');w.wait(lambda s:s['arena']['fast'],4);w.capture('duel');w.click('Защита');w.player()
 for _ in range(8):
  h=w.state()['arena']['units']['hans']
  if h['hp']<h['max_hp']:break
  w.click('Защита');w.player()
 w.click('Настойка');w.click(unit='hans');w.player();assert w.state()['arena']['potions']==1
 assert w.finish()=='victory';w.capture('victory')
 w.picker();w.scenario('Плечом к плечу','companions');s=w.state();assert s['arena']['units']['spirit']['row']=='back' and next(b for b in s['buttons'] if b['unit']=='spirit')['disabled'];w.capture('rows');w.finish()
 w.picker();w.scenario('Последняя настойка','tincture');w.capture('support');w.finish()
 w.picker();w.scenario('Шёпот леса','forest');w.click('Корни');w.click(unit='beast');w.player();assert w.state()['arena']['roots']==0
 w.click('Ворон');w.click(unit='hans');w.player();assert w.state()['arena']['raven']==0;w.capture('forest-help')
 w.click('Атака');w.click(unit='beast');was_busy=w.state()['arena']['busy'];w.click('Заново');w.player();assert w.state()['arena']['roots']==1 and w.state()['arena']['raven']==1;w.log({'action':'restart','was_busy':was_busy,'success':True});w.finish()
 w.picker();w.scenario('Цена предательства','betrayal')
 for _ in range(12):
  s=w.player();a=s['arena']
  if a['units']['mercenary']['team']==1:break
  w.click('Защита')
 else:raise RuntimeError('Betrayal not observed')
 s=w.state();assert s['arena']['order'].count('mercenary')==1;w.capture('betrayal');w.finish(defend=True);w.capture('defeat')
 w.picker();w.scenario('Лесная засада','ambush')
 for _ in range(10):
  s=w.player()
  if s['arena']['result']:break
  w.click('Уйти')
 s=w.player();w.capture('retreat-outcome');assert s['arena']['result'] in ['retreated','defeat']
 w.click('В меню');s=w.wait(lambda s:s['scene'].endswith('/MainMenu.tscn'),5)
 assert not s['clock_running'] and s['npc_count']==0 and s['clock']==420
 w.capture('menu-return');w.log({'action':'native-combat-success','success':True})
 (out/'result.json').write_text(json.dumps({'success':True,'final':s},ensure_ascii=False,indent=2));(out/'STOP').touch()
if __name__=='__main__':main()
