#!/usr/bin/env python3
"""NPC scenarios in the already-running real game. Only native WASD/E/F7/Esc.
Never seeks the clock, changes actor positions, or invokes gameplay methods.
"""
import argparse
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import time
from native_window_playtest import NativeWindow

WORKERS=['woodcutter','herbalist_brother']

def speed(window, wanted):
    for _ in range(4):
        if window.state()['clock_speed']==wanted:return
        window.pulse(['F7'],.03)
    raise RuntimeError('Native F7 did not select requested clock speed')

def record(window, label):
    target=window.output/(label+'.mp4')
    log=(window.output/(label+'-video.log')).open('w')
    proc=subprocess.Popen(['ffmpeg','-y','-loglevel','warning','-f','x11grab','-draw_mouse','0','-framerate','12','-video_size','960x540','-i',os.environ.get('DISPLAY',':98')+'+20,20','-an','-c:v','libx264','-preset','ultrafast','-crf','28','-pix_fmt','yuv420p',str(target)],stdout=log,stderr=log)
    return proc,log,time.time()

def stop_record(video):
    proc,log,_=video
    proc.send_signal(signal.SIGINT)
    try:proc.wait(timeout=8)
    except subprocess.TimeoutExpired:proc.terminate();proc.wait()
    log.close()

def trace(window, label, state):
    with (window.output/'npc-native-observations.jsonl').open('a') as f:
        f.write(json.dumps({'label':label,'wall_time':time.time(),'clock':state['clock'],'hero':state['position'],'world':state['world'],'residents':state['residents']},ensure_ascii=False)+'\n')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();w=NativeWindow(a.output)
    ids={id:r['body'] for id,r in w.state()['residents'].items()}
    source_speeds={id:w.state()['residents'][id]['source_speed'] for id in WORKERS}
    summary={'method':'Real Godot main scene, XTest OS keyboard input, read-only observer; no teleport or time seek','checks':[]}
    def check(value,label):
        summary['checks'].append({'label':label,'passed':bool(value)})
        print('PASS:' if value else 'FAIL:',label,flush=True)
        if not value:raise RuntimeError(label)
    assert w.state()['active_id']==''
    # Cover the first-appearance-after-virtual-work bug: stay indoors that morning.
    house=w.state()['doors']['inn']
    w.walk(house['approach'],'morning-inn-approach');w.pulse(['e'])
    inside=w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'])
    speed(w,30)
    w.wait(lambda s:all(s['residents'][id]['scene']=='logging' and not s['residents'][id]['present'] for id in WORKERS),30)
    check(all(w.state()['residents'][id]['distance_walked']<.1 for id in WORKERS),'workers first become visible only after a completely virtual morning departure')
    w.walk(inside['entry'],'morning-inn-exit');w.pulse(['e'])
    w.wait(lambda s:s['active_id']=='' and not s['busy']);speed(w,1)
    w.walk([1480,300],'north-observation-point')
    before={id:w.state()['residents'][id]['events'].get('return_from_work',0) for id in WORKERS}
    video=record(w,'workers-evening')
    try:
        speed(w,30);deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            s=w.state();trace(w,'wait-evening',s)
            if all(s['residents'][id]['events'].get('return_from_work',0)>before[id] for id in WORKERS):break
            time.sleep(.08)
        else:raise RuntimeError('No evening returns')
        speed(w,1)
        s=w.wait(lambda s:any(r['present'] and r['scene']=='village' and r['position'][1]>90 for id,r in s['residents'].items() if id in WORKERS),8)
        check(all(s['residents'][id]['body']==ids[id] and s['residents'][id]['scene']=='village' for id in WORKERS),'both original workers physically return from logging')
        w.capture('workers-evening-return')
        check(all(abs(s['residents'][id]['source_speed']-s['residents'][id]['runtime_speed'])<.001 and abs(s['residents'][id]['source_speed']-source_speeds[id])<.001 and not s['residents'][id]['source_alias'] for id in WORKERS),'native F7 reset restores actual worker speeds without mutating source data')
        for case in range(3):
            s=w.state()
            candidates=[(id,s['residents'][id]) for id in WORKERS if s['residents'][id]['present'] and s['residents'][id]['scene']=='village' and len(s['residents'][id]['upcoming_path'])>=11]
            if not candidates:raise RuntimeError('No traveling worker available for obstruction scenario')
            id,r=next((item for item in candidates if item[0]=='herbalist_brother'),candidates[0])
            goal=r['upcoming_path'][10]
            w.walk(goal,'stand-on-route-'+str(case+1))
            start=w.state()['residents'][id];held_at=w.state()['position'];samples=[]
            until=time.monotonic()+4.5
            while time.monotonic()<until:
                s=w.state();samples.append(s['residents'][id]);trace(w,'hans-block-'+str(case+1),s);time.sleep(.08)
            after=w.state()['residents'][id]
            progress=after['scene']!='village' or math.dist(start['position'],after['position'])>12
            approached=min(math.dist(row['position'],held_at) for row in samples if row['scene']=='village')<45
            check(progress and approached and w.state()['position']==held_at,'native route obstruction '+str(case+1)+': NPC continues without pushing Hans')
            w.capture('hans-block-'+str(case+1))
    finally:stop_record(video)
    # Outrun the brother to his own home, then observe his actual indoor arrival.
    speed(w,1)
    house=w.state()['doors']['herbalist'];before=w.state()['residents']['herbalist_brother']
    w.walk(house['approach'],'reach-herbalist-before-brother')
    w.pulse(['e']);inside=w.wait(lambda s:s['active_id']=='herbalist' and not s['busy'] and not s['locked'])
    entry=inside['entry'];w.walk([entry[0],entry[1]-32],'clear-inner-entry-for-resident')
    s=w.wait(lambda s:s['residents']['herbalist_brother']['scene']=='herbalist' and s['residents']['herbalist_brother']['present'],60)
    check(s['residents']['herbalist_brother']['body']==ids['herbalist_brother'],'same returning brother becomes visible in correct interior')
    check(len({r['body'] for r in s['residents'].values()})==9,'nine unique residents across native scene transitions')
    w.capture('brother-home-arrival')
    s=w.wait(lambda s:s['residents']['herbalist_brother']['state']==2,12)
    r=s['residents']['herbalist_brother'];w.walk([r['position'][0]+22,r['position'][1]],'approach-returned-resident')
    w.wait(lambda s:'HerbalistBrother' in s['target'] and 'Поговорить' in s['prompt'],3)
    w.pulse(['e']);w.wait(lambda s:s['dialogue'] and s['locked']);time.sleep(.35)
    w.capture('returned-resident-dialogue')
    check(w.state()['dialogue'] and not w.state()['info'],'real E dialogue opens after indoor arrival')
    w.pulse(['Escape']);s=w.wait(lambda s:not s['dialogue'] and not s['locked'])
    check(s['residents']['herbalist_brother']['state']!=5,'returned resident resumes after native dialogue')
    w.walk(entry,'exit-herbalist-after-dialogue');w.pulse(['e']);w.wait(lambda s:s['active_id']=='' and not s['busy'])
    w.walk([1480,300],'return-to-north-for-next-morning')
    before={id:w.state()['residents'][id]['events'].get('left_for_work',0) for id in WORKERS}
    video=record(w,'workers-morning')
    departure_time=None
    try:
        speed(w,30);deadline=time.monotonic()+100
        while time.monotonic()<deadline:
            s=w.state();trace(w,'wait-morning',s)
            if departure_time is None and any(r['present'] and r['scene']=='village' and r['mode']=='travel' and r['destination'] and r['destination'][1]<60 and 80<r['position'][1]<320 for id,r in s['residents'].items() if id in WORKERS):
                departure_time=time.time();w.log({'action':'workers-seen-leaving','video_seconds':departure_time-video[2],'workers':{id:s['residents'][id] for id in WORKERS}})
            if all(s['residents'][id]['events'].get('left_for_work',0)>before[id] and s['residents'][id]['scene']=='logging' and not s['residents'][id]['present'] for id in WORKERS):break
            time.sleep(.06)
        else:raise RuntimeError('Workers did not leave on next morning')
        check(departure_time is not None,'both workers followed along the real northern exit route')
        check(all(w.state()['residents'][id]['body']==ids[id] for id in WORKERS),'same workers leave visible map and enter logical logging state')
    finally:stop_record(video)
    check({id:r['body'] for id,r in w.state()['residents'].items()}==ids,'all nine IDs persist for evening, dialogue and next morning')
    summary['passed']=all(row['passed'] for row in summary['checks']);summary['final_clock']=w.state()['clock'];summary['worker_ids']={id:ids[id] for id in WORKERS}
    (w.output/'npc-native-results.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print('RESULT:',len(summary['checks']),'native NPC scenarios passed',flush=True)

if __name__=='__main__':main()
