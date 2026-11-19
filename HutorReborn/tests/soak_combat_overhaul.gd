extends "res://tests/verify_combat_ui_61.gd"
var samples:Array=[]
var keys:=0
var contacts:=0
var began:=0
var last_sample:=0
func _process(_delta:float) -> bool:
    if began>0 and Time.get_ticks_msec()-last_sample>5000:
        last_sample=Time.get_ticks_msec()
        samples.append({"seconds":(last_sample-began)/1000.0,"nodes":get_node_count(),"static_memory":OS.get_static_memory_usage(),"fps":Performance.get_monitor(Performance.TIME_FPS),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000})
    return false
func run() -> void:
    var seconds:=maxf(180,float(OS.get_environment("COMBAT_SOAK_SECONDS")))
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    arena.animation_keyframe.connect(func(event:Dictionary):
        keys+=1
        if event.type=="attack" and event.hit:
            for child in arena.get_children():
                if child.get_script()==preload("res://scripts/combat/animation/combat_contact.gd"):contacts+=1;break)
    began=Time.get_ticks_msec();last_sample=began
    var battles:=0;var actions:=0;var scenarios:=["duel","forest","companions"]
    while Time.get_ticks_msec()-began<seconds*1000:
        arena._start_scenario(scenarios[battles%3]);await ready_turn(arena)
        var deadline:=Time.get_ticks_msec()+45000
        while arena.battle.result=="" and Time.get_ticks_msec()<deadline:
            if not arena.busy and arena.battle.actor() and arena.battle.actor().team==0:
                var targets:Array=arena.battle.targets("attack")
                if not targets.is_empty():arena._target(targets[0])
                else:arena._select_action("defend")
                actions+=1
            await create_timer(.08).timeout
            if Time.get_ticks_msec()-began>=seconds*1000:break
        if arena.battle.result!="":battles+=1
        else:
            check(Time.get_ticks_msec()-began>=seconds*1000,"battle did not hang beyond 45sec")
            break
    arena._cancel();await create_timer(1).timeout
    check(keys>20 and contacts>10,"real keyframes and contact effects observed")
    check(battles>=3 and actions>10,"repeated duel/forest/group fights")
    check(samples.size()>=30,"at least 3 minutes of real-time samples")
    var node_min:=100000;var node_max:=0
    for sample in samples:node_min=mini(node_min,int(sample.nodes));node_max=maxi(node_max,int(sample.nodes))
    check(node_max-node_min<120,"bounded node count under repeated fights")
    var report:={"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"elapsed_seconds":(Time.get_ticks_msec()-began)/1000.0,"completed_battles":battles,"player_actions":actions,"keyframes":keys,"observed_contact_effects":contacts,"node_range":[node_min,node_max],"samples":samples,"passed":passed,"failed":failed,"limitation":"Linux software renderer; bounded nodes/observed memory over this interval do not prove absence of all leaks or Windows GPU performance."}
    var path:=OS.get_environment("COMBAT_SOAK_REPORT")
    if not path.is_empty():
        var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n")
    print("RESULT: ",passed," soak checks passed, ",failed," failed; ",report.elapsed_seconds," seconds; ",battles," battles")
    quit(0 if failed==0 else 1)
