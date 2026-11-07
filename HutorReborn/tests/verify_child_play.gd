extends "res://tests/verify_interiors.gd"
func run()->void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var world:Node2D=current_scene;var life:Node=root.get_node("VillageLife")
    life.clock.running=false;life.clock.seek(600)
    var child:HutorResident=life.states[&"woodcutter_son"].actor
    var mother:HutorResident=life.states[&"woodcutter_wife"].actor
    # Hans watches the same child from nearby, without moving onto his destination.
    world.player.position=Vector2(1670,940)
    life.clock.set_speed(10);life.clock.running=true
    var actions:Dictionary={};var frames_seen:Dictionary={}
    var ran:=false;var visited:=false;var watched:=false;var invalid:=""
    var before:=child.position
    var end:=Time.get_ticks_msec()+14000
    while life.clock.absolute_minutes<660 and Time.get_ticks_msec()<end:
        await physics_frame
        var r:HutorDailyResidentState=life.states[&"woodcutter_son"]
        var sprite:AnimatedSprite2D=child.get_node("AnimatedSprite2D")
        if child.state==HutorResident.State.WAITING:
            actions[r.activity]=true
            if r.activity in [&"play_stick",&"kneel_toy"]:
                if not frames_seen.has(r.activity):frames_seen[r.activity]={}
                frames_seen[r.activity][sprite.frame]=true
            if r.activity==&"visit_mother" and child.position.distance_to(mother.position)<65:visited=true
        if child.state==HutorResident.State.MOVING and child.current_step().label=="run_yard" and not child.velocity.is_zero_approx():
            ran=ran or String(sprite.animation).begins_with("run_")
        watched=watched or child.activity_controller.reactions.looks_started>0
        if not Rect2(1180,740,730,970).grow(20).has_point(child.position):invalid="safe zone escaped"
        if child.position.distance_to(before)>child.definition.speed*child.get_physics_process_delta_time()+1:invalid="teleport"
        before=child.position
    life.clock.running=false
    check(actions.has(&"play_stick") and actions.has(&"kneel_toy") and actions.has(&"visit_mother"),"boy completes play, kneeling and family visits")
    check(ran,"actual run animation plays while crossing yard")
    check(frames_seen.get(&"play_stick",{}).size()>1 and frames_seen.get(&"kneel_toy",{}).size()>1,"original stick and crouch animations advance through real frames")
    check(visited,"boy reaches mother's current position rather than stale yard marker")
    check(watched,"boy briefly looks at nearby Hans during play")
    check(invalid.is_empty(),"play remains continuous and inside safe area: "+invalid)
    var id:=child.get_instance_id()
    life.clock.seek(1070);life.clock.running=true;life.clock.set_speed(30)
    end=Time.get_ticks_msec()+9000
    while life.states[&"woodcutter_son"].scene!=&"woodcutter" and Time.get_ticks_msec()<end:await physics_frame
    life.clock.running=false
    check(life.states[&"woodcutter_son"].scene==&"woodcutter" and child.get_instance_id()==id,"same boy returns home in evening through his door")
    print("RESULT: ",passed," child-play checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
