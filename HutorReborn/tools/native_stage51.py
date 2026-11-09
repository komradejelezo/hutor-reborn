#!/usr/bin/env python3
"""Visit all six furnished rooms using actual OS keys in the normal Godot window."""
import argparse
import json
import math
import time
from native_window_playtest import NativeWindow

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True)
    parser.add_argument('--houses',nargs='+',choices=['inn','elder','herbalist','woodcutter','old_man','storehouse'])
    args=parser.parse_args()
    w=NativeWindow(args.output)
    initial=w.state()
    identities={key:value['body'] for key,value in initial['residents'].items()}
    result={'method':'Real normal main scene, native XTest WASD/E/F7/Esc, read-only observer', 'houses':{}}
    # Wait with real F7, without seeking. The later residential visits occur at night.
    for _ in range(3):
        if w.state()['clock_speed']==30:break
        w.pulse(['F7'])
    w.wait(lambda s:s['clock']%1440>=1180,90)
    for _ in range(3):
        if w.state()['clock_speed']==1:break
        w.pulse(['F7'])
    checks={
        'inn':[[320,180],[435,90],[435,285]],
        'elder':[[145,230],[240,100],[338,92]],
        'herbalist':[[110,190],[210,192],[240,82]],
        'woodcutter':[[130,210],[290,155],[334,223]],
        'old_man':[[90,150],[155,150],[123,130]],
        'storehouse':[[175,78],[215,205],[160,260]],
    }
    origins={'inn':[160,128],'elder':[256,160],'herbalist':[256,160], 'woodcutter':[288,160],'old_man':[352,192],'storehouse':[320,160]}
    for house,points in checks.items():
        if args.houses and house not in args.houses:continue
        start=w.state();door=start['doors'][house]
        w.walk(door['approach'],'approach-'+house)
        w.wait(lambda s:s['prompt']=='E — Войти',2)
        assert w.state()['prompt']=='E — Войти'
        w.pulse(['e'])
        inside=w.wait(lambda s:s['world']==door['scene'] and not s['busy'] and not s['locked'])
        assert inside['hero']==initial['hero'] and not inside['info']
        assert all(abs(v-1.3)<.001 for v in inside['camera_zoom'])
        origin=origins[house]
        for i,point in enumerate(points):
            w.walk([origin[0]+point[0],origin[1]+point[1]],f'{house}-explore-{i}')
        # Face the main room from a central accessible point for a real full-room image.
        center={'inn':[480,304],'elder':[480,328],'herbalist':[464,304], 'woodcutter':[480,304],'old_man':[496,320],'storehouse':[496,304]}[house]
        w.walk(center,house+'-photo-position')
        time.sleep(.7)  # Let the unchanged smooth camera catch the actual walk.
        w.capture(house+'-interior')
        residents=[key for key,value in w.state()['residents'].items() if value['present'] and value['scene']==house]
        if house=='inn':
            # The bartender's existing talk marker is in front of the counter.
            w.walk([430,286],'inn-talk-approach')
            s=w.state()
            if 'Interaction' in s['target'] and 'InteriorDoor' not in s['target']:
                w.pulse(['e']);w.wait(lambda s:s['dialogue']);time.sleep(.35)
                w.capture('inn-dialogue');w.pulse(['Escape']);w.wait(lambda s:not s['dialogue'] and not s['locked'])
        w.walk(inside['entry'],'exit-'+house)
        w.wait(lambda s:s['prompt']=='E — Выйти',2)
        assert w.state()['prompt']=='E — Выйти'
        w.pulse(['e'])
        outside=w.wait(lambda s:s['active_id']=='' and not s['busy'] and not s['locked'])
        assert outside['world']==start['world'] and math.dist(outside['position'],door['approach'])<1
        assert outside['camera_zoom']==start['camera_zoom']
        assert outside['hero']==initial['hero']
        assert {key:value['body'] for key,value in outside['residents'].items()}==identities
        result['houses'][house]={'entry_exit':True,'walk_points':3,'camera':True,'identities':True,'residents_observed':residents,'clock':outside['clock']}
        w.log({'action':'stage51-house-passed','house':house,**result['houses'][house]})
        (w.output/'stage51-native-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'PASS: {len(result["houses"])} actual room visits, {len(result["houses"])*3} exploration routes, camera and nine identities preserved',flush=True)

if __name__=='__main__':main()
