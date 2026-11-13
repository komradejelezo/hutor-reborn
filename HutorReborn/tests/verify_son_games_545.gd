extends "res://tests/verify_interiors.gd"
## Real game physics over time, with a frozen clock-of-day, not forced game poses.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife")
    life.clock.running=false;life.clock.seek(600);await frames(8)
    var record:HutorDailyResidentState=life.states[&"woodcutter_son"]
    var child:HutorResident=record.actor
    var sprite:AnimatedSprite2D=child.get_node("AnimatedSprite2D")
    var world:Node2D=travel.active_world
    world.player.position=Vector2(1400,1300)
    var body_id:=child.get_instance_id();var source_speed:=record.original.speed
    var clips:Dictionary={};var phases:Dictionary={};var speeds:Dictionary={}
    var before:=child.position;var invalid:="";var checked_pause:=false
    for i in 10500:
        await physics_frame
        var phase:String=child.get("play_phase")
        clips[sprite.animation]=true;phases[phase]=true
        if not child.velocity.is_zero_approx():speeds["run" if String(sprite.animation).begins_with("run_") else "walk"]=true
        var moved:=child.position.distance_to(before)
        if moved>77.5/60.0+.12:invalid="discontinuous position"
        if not Rect2(1180,740,730,970).has_point(child.position):invalid="safe rectangle escaped"
        if not free_at(world,child.position,child.definition.foot_radius):invalid="static collision overlap"
        before=child.position
        if phase=="chase" and not checked_pause:
            var saved_phase:String=phase;var position:=child.position;var ball:Sprite2D=child.get("_ball");var ball_position:=ball.position
            child.begin_conversation();await frames(30)
            check(child.state==child.State.TALKING and child.velocity==Vector2.ZERO and child.position==position,"conversation immediately stops chase")
            check(child.get("play_phase")==saved_phase and ball.position==ball_position,"conversation pauses ball and child sequence")
            child.end_conversation();check(child.get("play_phase")==saved_phase,"same chase resumes after conversation")
            checked_pause=true
        if child.get("play_counts").has("return") and phases.has("jump") and phases.has("inspect") and checked_pause and speeds.size()==2:break
    for phase in ["kick","chase","pickup","rise_return","return","joy","kneel","inspect","rise","jump","rest"]:
        check(phases.has(phase),"actual live-game phase: "+phase)
    for clip in ["work_ball","work_kneel_down","work_kneel","work_stand_up","work_jump","work_joy"]:
        check(clips.has(StringName(clip)),"drawn action is actually played: "+clip)
    check(speeds.size()==2,"live routine contains distinct walk and run movement")
    check(invalid.is_empty(),"continuous safe-area physics: "+invalid)
    check(checked_pause,"dialogue interruption was exercised during actual chase")
    check(record.original.speed==source_speed and source_speed==62,"source definition speed was not mutated")
    # Leave while a game is active: no orphan ball, same identity on re-entry.
    check(travel.request_transition(&"woodcutter"),"family home entry");await wait_transition()
    check(not is_instance_valid(child.get("_ball")),"parked game leaves no floor toy behind")
    check(travel.request_transition(&"woodcutter",true),"return outdoors");await wait_transition()
    check(record.actor.get_instance_id()==body_id and child.is_inside_tree(),"same child and schedule survive player scene changes")
    life.clock.seek(1070);life.clock.set_speed(30);life.clock.running=true
    for i in 900:
        await physics_frame
        if record.scene==&"woodcutter":break
    life.clock.running=false
    check(record.scene==&"woodcutter" and record.actor.get_instance_id()==body_id,"original evening homeward door transfer remains operational")
    print("PHASES: ",phases," CLIPS: ",clips," COUNTS: ",child.get("play_counts"))
    print("RESULT: ",passed," son live-game checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
