#!/usr/bin/env python3
"""Normal window gameplay; real OS keys only. Observer reads, never drives gameplay."""
import argparse
import json
import os
import signal
import subprocess
import time
from native_window_playtest import NativeWindow

def speed(w,value):
    for _ in range(4):
        if w.state()['clock_speed']==value:return
        w.pulse(['F7'],.1)
    raise RuntimeError('F7 did not select requested speed')

def natural_glance(w):
    door=w.state()['doors']['inn']
    w.walk(door['approach'],'natural-cue-inn-approach')
    w.wait(lambda s:s['prompt']=='E — Войти');w.pulse(['e'])
    inside=w.wait(lambda s:s['active_id']=='inn' and not s['busy'] and not s['locked'])
    w.walk([480,304],'natural-cue-readable-camera')
    if w.state()['ambient']['phase']=='night':
        speed(w,30);w.wait(lambda s:s['ambient']['phase']=='morning',90)
    speed(w,1);before=w.state()['ambient']['glances']
    with (w.output/'natural-video.log').open('w') as log:
        video=subprocess.Popen(['ffmpeg','-y','-loglevel','warning','-f','x11grab','-draw_mouse','0','-framerate','12','-video_size','960x540','-i',os.environ.get('DISPLAY',':98')+'+20,20','-an','-c:v','libx264','-preset','ultrafast','-crf','28','-pix_fmt','yuv420p',str(w.output/'inn-natural-details.mp4')],stdout=log,stderr=log)
        try:
            state=w.wait(lambda s:s['ambient']['glances']>before,85)
            w.log({'action':'natural-shelf-glance-observed','ambient':state['ambient'],'residents':state['residents']})
            w.capture('inn-natural-glance');time.sleep(2)
        finally:
            video.send_signal(signal.SIGINT);video.wait(timeout=10)
    state=w.wait(lambda s:s['residents']['innkeeper']['state']==2,15)
    resident=state['residents']['innkeeper']
    offset=70 if resident['activity'] in ['prepare_inn','wipe_mug','arrange_dishes'] else 0
    w.walk([resident['position'][0],resident['position'][1]+offset+18],'natural-cue-talk-approach')
    w.wait(lambda s:'Innkeeper' in s['target'] and 'Поговорить' in s['prompt'],4)
    w.pulse(['e']);w.wait(lambda s:s['dialogue'] and s['locked']);time.sleep(.4)
    w.capture('inn-ambient-dialogue');w.pulse(['Escape'])
    w.wait(lambda s:not s['dialogue'] and not s['locked'])
    w.log({'action':'natural-cue-dialogue-resumed','success':True})
    w.walk(inside['entry'],'natural-cue-exit');w.wait(lambda s:s['prompt']=='E — Выйти');w.pulse(['e'])
    w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'])
    (w.output/'natural-cue-result.json').write_text(json.dumps({'glance_observed':True,'dialogue_and_resume':True,'returned_outdoors':True,'ambient':w.state()['ambient']},ensure_ascii=False,indent=2)+'\n')
    print('PASS: natural visible shelf glance, real dialogue and return',flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True)
    p.add_argument('--glance-only',action='store_true')
    a=p.parse_args();w=NativeWindow(a.output)
    if a.glance_only:return natural_glance(w)
    result={'method':'Normal main, OS XTest WASD/E/F3/F7/Escape; read-only observer','phases':{},'houses':{}}
    speed(w,30)
    for phase in ['day','evening','night']:
        w.wait(lambda s:s['ambient']['phase']==phase,90)
        speed(w,1);time.sleep(2)
        s=w.state();data=s['ambient']
        assert data['bed']==('forest_day' if phase=='day' else 'wind_bed')
        assert data['voices']<=6 and data['active_components']==1
        w.capture('village-'+phase)
        result['phases'][phase]=data
        if phase!='night':speed(w,30)
    w.pulse(['F3']);w.wait(lambda s:s['ambient']['voices']==0 and not s['ambient']['motes'],4)
    w.pulse(['F3']);w.wait(lambda s:s['ambient']['voices']>0,4)
    result['f3_off_on']=True
    for house in ['inn','elder','herbalist','woodcutter','old_man','storehouse']:
        start=w.state();ids={key:value['body'] for key,value in start['residents'].items()}
        door=start['doors'][house]
        w.walk(door['approach'],'approach-'+house)
        w.wait(lambda s:s['prompt']=='E — Войти',3);w.pulse(['e'])
        inside=w.wait(lambda s:s['active_id']==house and not s['busy'] and not s['locked'])
        w.wait(lambda s:s['ambient']['scene']==house and s['ambient']['bed']=='',4)
        entry=inside['entry'];w.walk([entry[0],entry[1]-28],house+'-walk-inside')
        time.sleep(3)
        data=w.state()['ambient']
        assert data['dust'] and data['active_components']==1 and data['pool_size']==6 and data['voices']<=6
        assert data['hearth']==(house!='storehouse')
        assert data['particle_capacity']<=24
        w.capture(house+'-atmosphere')
        w.walk(entry,'exit-'+house);w.wait(lambda s:s['prompt']=='E — Выйти',3);w.pulse(['e'])
        s=w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'])
        assert {key:value['body'] for key,value in s['residents'].items()}==ids
        w.wait(lambda s:s['ambient']['scene']=='village' and s['ambient']['active_components']==1,3)
        result['houses'][house]={'entered_exited':True,'same_nine_ids':True,'ambient':data}
        w.log({'action':'ambient-house-passed','house':house,'ambient':data})
    assert w.state()['ambient']['peak_voices']<=6
    result['final']=w.state()['ambient']
    (w.output/'ambient-native-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('PASS: real day/evening/night, F3 and all six interior ambience roundtrips',flush=True)

if __name__=='__main__':main()
