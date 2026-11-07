extends "res://tests/verify_interiors.gd"
## Capture only genuine schedule-driven movement/poses. Debug seek is explicit.
var life:Node
var output:=""
var observations:Array[Dictionary]=[]
func shot(label:String)->void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    var rows:Array=[]
    for record:HutorDailyResidentState in life.states.values():
        if record.actor.is_inside_tree():rows.append({"id":String(record.id),"position":str(record.actor.position),"mode":String(record.mode),"activity":String(record.activity),"clip":String(record.actor.get_node("AnimatedSprite2D").animation)})
    observations.append({"capture":label,"minute":life.clock.absolute_minutes,"residents":rows})
func run()->void:
    output=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output)
    travel=root.get_node("InteriorTravel");life=root.get_node("VillageLife")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var world:Node2D=current_scene
    life.clock.running=false;life.clock.seek(479)
    world.player.position=Vector2(1480,300)
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.reset_smoothing();camera.force_update_scroll()
    life.clock.set_speed(10);life.clock.running=true
    var end:=Time.get_ticks_msec()+15000
    var departure:=false
    while Time.get_ticks_msec()<end:
        await physics_frame
        var a:HutorDailyResidentState=life.states[&"woodcutter"]
        var b:HutorDailyResidentState=life.states[&"herbalist_brother"]
        if not departure and a.mode==&"travel" and a.desired_scene==&"logging" and a.actor.position.y>100 and a.actor.position.y<180:await shot("logging-departure");departure=true
        if a.scene==&"logging" and b.scene==&"logging":break
    check(departure and life.states[&"herbalist_brother"].scene==&"logging","both physical logging departures captured")
    life.clock.running=false;life.clock.seek(1079);life.clock.running=true
    var returning:=false;end=Time.get_ticks_msec()+15000
    while Time.get_ticks_msec()<end:
        await physics_frame
        var a:HutorDailyResidentState=life.states[&"woodcutter"]
        var b:HutorDailyResidentState=life.states[&"herbalist_brother"]
        if not returning and a.scene==&"village" and a.mode==&"travel" and a.actor.position.y>120:await shot("logging-return");returning=true
        if a.scene==&"woodcutter" and b.scene==&"herbalist":break
    check(returning and life.states[&"woodcutter"].scene==&"woodcutter" and life.states[&"herbalist_brother"].scene==&"herbalist","both workers visibly return and reach their own homes")
    life.clock.running=false;life.clock.seek(600)
    world.player.position=Vector2(1690,940);camera.reset_smoothing();camera.force_update_scroll()
    life.clock.set_speed(5);life.clock.running=true
    var captured:Dictionary={};end=Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<end and captured.size()<4:
        await physics_frame
        var r:HutorDailyResidentState=life.states[&"woodcutter_son"]
        var actor:HutorResident=r.actor;var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
        var label:=""
        if actor.state==HutorResident.State.MOVING and String(sprite.animation).begins_with("run_"):label="child-runs"
        elif actor.state==HutorResident.State.WAITING:
            if sprite.animation==&"work_play":label="child-stick"
            elif sprite.animation==&"work_kneel":label="child-kneels"
            elif r.activity==&"visit_mother" and actor.position.distance_to(life.states[&"woodcutter_wife"].actor.position)<65:label="child-mother"
        if not label.is_empty() and not captured.has(label):await shot(label);captured[label]=true
    check(captured.size()==4,"actual run, stick, kneeling and mother visit captured")
    life.clock.running=false
    var file:=FileAccess.open(output.path_join("motion-captures.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(observations,"  "))
    print("RESULT: ",passed," motion capture checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
