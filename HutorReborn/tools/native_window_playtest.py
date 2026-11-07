#!/usr/bin/env python3
"""Control the real Godot X11 window with OS keyboard events; observe read-only JSON.
No SceneTree fixture, actor teleportation, clock seek or Input.parse_input_event.
"""
import argparse
import ctypes as C
import ctypes.util
import json
import math
import os
from pathlib import Path
import subprocess
import time
from verify_normal_startup import observer_override

class NativeWindow:
    def __init__(self, output):
        self.output = Path(output)
        self.x = C.CDLL(ctypes.util.find_library('X11'))
        self.xt = C.CDLL(ctypes.util.find_library('Xtst'))
        self.x.XOpenDisplay.argtypes = [C.c_char_p]; self.x.XOpenDisplay.restype = C.c_void_p
        self.display = self.x.XOpenDisplay(os.environ.get('DISPLAY', ':98').encode())
        if not self.display: raise RuntimeError('X11 display unavailable')
        self.x.XDefaultRootWindow.argtypes=[C.c_void_p];self.x.XDefaultRootWindow.restype=C.c_ulong
        self.x.XQueryTree.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ulong)),C.POINTER(C.c_uint)]
        self.x.XFetchName.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_char_p)]
        self.x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
        self.x.XFlush.argtypes=[C.c_void_p];self.x.XFree.argtypes=[C.c_void_p]
        self.x.XStringToKeysym.argtypes=[C.c_char_p];self.x.XStringToKeysym.restype=C.c_ulong
        self.x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong];self.x.XKeysymToKeycode.restype=C.c_uint
        self.xt.XTestFakeKeyEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
        root=self.x.XDefaultRootWindow(self.display);r=C.c_ulong();p=C.c_ulong();c=C.POINTER(C.c_ulong)();n=C.c_uint()
        self.x.XQueryTree(self.display,root,C.byref(r),C.byref(p),C.byref(c),C.byref(n))
        choices=[]
        for i in range(n.value):
            name=C.c_char_p();self.x.XFetchName(self.display,c[i],C.byref(name))
            if name.value and b'Hutor Reborn' in name.value:choices.append(c[i])
            if name.value:self.x.XFree(name)
        self.x.XFree(c)
        if len(choices)!=1:raise RuntimeError('Expected exactly one Godot game window; close other game instances')
        self.window=max(choices)
        self.x.XSetInputFocus(self.display,self.window,1,0);self.x.XFlush(self.display)
        self.sequence=int(time.time()*1000)

    def state(self):
        return json.loads((self.output/'state.json').read_text())

    def pulse(self, keys, seconds=.08):
        codes=[self.x.XKeysymToKeycode(self.display,self.x.XStringToKeysym(key.encode())) for key in keys]
        try:
            for code in codes:self.xt.XTestFakeKeyEvent(self.display,code,1,0)
            self.x.XFlush(self.display)
            began=time.monotonic();before=self.state()['position']
            while time.monotonic()-began<seconds or (set(keys)&set('wasd') and math.dist(before,self.state()['position'])<.5 and time.monotonic()-began<.6):
                time.sleep(.01)
        finally:
            for code in codes:self.xt.XTestFakeKeyEvent(self.display,code,0,0)
            self.x.XFlush(self.display)
        old_tick=self.state()['tick'];end=time.monotonic()+2
        while self.state()['tick']<=old_tick and time.monotonic()<end:time.sleep(.015)
        return self.state()

    def wait(self, predicate, seconds=8):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            s=self.state()
            if predicate(s):return s
            time.sleep(.04)
        raise RuntimeError('Runtime condition timed out: '+json.dumps(self.state(),ensure_ascii=False)[:700])

    def route(self, goal):
        self.sequence+=1
        query=self.output/'query.json';tmp=query.with_suffix('.tmp')
        tmp.write_text(json.dumps({'sequence':self.sequence,'goal':goal}));tmp.replace(query)
        return self.wait(lambda s:s.get('route',{}).get('sequence')==self.sequence,3)['route']['points']

    def walk(self, goal, label='walk'):
        start=self.state();world=start['world'];began=time.monotonic()
        points=self.route(goal)
        if not points:raise RuntimeError('No static route to '+str(goal))
        for point in points[1:]:
            stalled=0
            for attempt in range(30):
                s=self.state()
                if s['world']!=world or s['locked']:raise RuntimeError('Unexpected scene/modal during walking')
                dx,dy=point[0]-s['position'][0],point[1]-s['position'][1]
                distance=math.hypot(dx,dy)
                if distance<8:break
                keys=[]
                if abs(dx)>5:keys.append('d' if dx>0 else 'a')
                if abs(dy)>5:keys.append('s' if dy>0 else 'w')
                if not keys:break
                after=self.pulse(keys,min(.18,max(.08,(distance-3)/94)))
                movement=math.dist(s['position'],after['position'])
                stalled=stalled+1 if movement<.4 else 0
                if stalled>=4:raise RuntimeError('Physically blocked at '+str(after['position'])+' toward '+str(point))
            else:raise RuntimeError('Could not reach waypoint '+str(point))
            if time.monotonic()-began>120:raise RuntimeError('Walk deadline exceeded')
        result=self.state()
        if math.dist(goal,result['position'])>10:raise RuntimeError('Did not reach requested position')
        self.log({'action':label,'from':start['position'],'to':result['position'],'world':world,'seconds':time.monotonic()-began,'clock':result['clock']})
        return result

    def capture(self, label):
        path=self.output/(label+'.png')
        r=subprocess.run(['ffmpeg','-y','-loglevel','error','-f','x11grab','-draw_mouse','0','-video_size','960x540','-i',os.environ.get('DISPLAY',':98')+'+20,20','-frames:v','1',str(path)],capture_output=True,text=True)
        if r.returncode or not path.exists():raise RuntimeError('Native screenshot failed: '+r.stderr)
        self.log({'action':'screenshot','file':path.name,'state':self.state()})

    def log(self, record):
        record['wall_time']=time.time()
        with (self.output/'native-actions.jsonl').open('a') as f:f.write(json.dumps(record,ensure_ascii=False)+'\n')
        print('NATIVE',record.get('action'),record.get('to',record.get('file','')),flush=True)

    def door(self, building):
        before=self.state()
        assert before['active_id']=='', 'Start outdoors'
        ids={id:r['body'] for id,r in before['residents'].items()}
        door=before['doors'][building]
        self.walk(door['approach'],'approach-'+building)
        focused=self.wait(lambda s:s['prompt']=='E — Войти' and building.lower() in str(s['target']).lower(),2) if building=='inn' else self.state()
        assert focused['prompt']=='E — Войти', focused['prompt']
        self.capture(building+'-door')
        self.pulse(['e'])
        inside=self.wait(lambda s:s['world']==door['scene'] and not s['busy'] and not s['locked'])
        assert inside['hero']==before['hero'] and not inside['info']
        assert inside['camera_zoom']==[1.3,1.3] or all(abs(v-1.3)<.001 for v in inside['camera_zoom'])
        assert {id:r['body'] for id,r in inside['residents'].items()}==ids
        self.capture(building+'-inside')
        entry=inside['entry'];self.walk([entry[0],entry[1]-24],'inside-walk-'+building)
        self.walk(entry,'inside-exit-'+building)
        assert self.state()['prompt']=='E — Выйти'
        self.pulse(['e'])
        outside=self.wait(lambda s:s['active_id']=='' and s['world']==before['world'] and not s['busy'] and not s['locked'])
        assert outside['hero']==before['hero'] and outside['clock']>=before['clock']
        assert outside['camera_zoom']==before['camera_zoom'] and math.dist(outside['position'],door['approach'])<1
        assert {id:r['body'] for id,r in outside['residents'].items()}==ids
        self.capture(building+'-return')
        self.log({'action':'door-roundtrip','building':building,'success':True,'scene':door['scene'],'hero':outside['hero'],'npc_ids':ids,'clock_before':before['clock'],'clock_after':outside['clock']})

def launch(output, project):
    if (output/'state.json').exists() or (output/'STOP').exists():raise RuntimeError('Use a fresh output directory for a new native session')
    output.mkdir(parents=True,exist_ok=True)
    with observer_override(project):
        with (output/'game.log').open('w') as log:
            proc=subprocess.Popen(['godot','--path',str(project),'--audio-driver','Dummy','--position','20,20','--',f'--runtime-output={output/"state.json"}',f'--runtime-query={output/"query.json"}'],stdout=log,stderr=log)
            try:
                deadline=time.monotonic()+40
                while not (output/'state.json').exists() and time.monotonic()<deadline:
                    if proc.poll() is not None:raise RuntimeError('Game exited during startup')
                    time.sleep(.1)
                if not (output/'state.json').exists():raise RuntimeError('Read-only observer unavailable')
                print('READY native main scene, PID',proc.pid,flush=True)
                while proc.poll() is None and not (output/'STOP').exists():time.sleep(.3)
            finally:
                if proc.poll() is None:proc.terminate()
                try:proc.wait(timeout=5)
                except subprocess.TimeoutExpired:proc.kill();proc.wait()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['launch','door','walk','tap','capture'])
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('values',nargs='*')
    a=p.parse_args()
    if a.action=='launch':return launch(a.output.resolve(),a.project.resolve())
    window=NativeWindow(a.output.resolve())
    if a.action=='door':window.door(a.values[0])
    elif a.action=='walk':window.walk([float(v) for v in a.values])
    elif a.action=='tap':window.pulse(a.values)
    elif a.action=='capture':window.capture(a.values[0])

if __name__=='__main__':main()
