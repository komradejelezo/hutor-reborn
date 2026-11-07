extends "res://tests/verify_interiors.gd"
## Actual arrival, playback and E conversations; no fabricated WAITING poses.
var life:Node
var captures:=""
func settled(actor:HutorResident)->void:
    var end:=Time.get_ticks_msec()+9000
    while actor.state!=HutorResident.State.WAITING and Time.get_ticks_msec()<end:await physics_frame
    check(actor.state==HutorResident.State.WAITING,String(actor.definition.id)+" reaches the actual occupation")
func close_conversation(manager:Node)->void:
    manager.close_dialogue()
    var deadline:=Time.get_ticks_msec()+2000
    while manager.is_active() and Time.get_ticks_msec()<deadline:await process_frame
    check(not manager.is_active(),"dialogue closing animation completes within deadline")
    await frames(2)
func shot(label:String)->void:
    if captures.is_empty():return
    var world:Node2D=travel.active_world
    var camera:Camera2D=world.player.get_node("Camera2D")
    var previous:=camera.position
    # Review framing only; preserve the gameplay zoom and restore the offset.
    camera.position=world.room_bounds.get_center()-world.player.position
    camera.reset_smoothing();camera.force_update_scroll();await frames(3)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(captures.path_join(label+".png"))
    camera.position=previous;camera.reset_smoothing();camera.force_update_scroll()
func run()->void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=")
    if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
    travel=root.get_node("InteriorTravel");life=root.get_node("VillageLife")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    life.clock.running=false
    var identities:Dictionary={}
    for id in life.states:identities[id]=life.states[id].actor.get_instance_id()
    var manager:Node=root.get_node("DialogueManager")
    var cases:=[
        [&"woodcutter",425.0],[&"woodcutter_wife",425.0],[&"woodcutter_son",425.0],
        [&"innkeeper",600.0],[&"innkeeper_wife",600.0],[&"herbalist",665.0],
        [&"herbalist_brother",1215.0],[&"elder",375.0],[&"old_man",1215.0]]
    for spec in cases:
        var id:StringName=spec[0];life.clock.seek(spec[1])
        var r:HutorDailyResidentState=life.states[id]
        check(travel.request_transition(r.schedule.home),String(id)+" existing home entry")
        await wait_transition()
        var world:Node2D=travel.active_world;var hero:CharacterBody2D=world.player
        var actor:HutorResident=r.actor
        check(actor.is_inside_tree() and actor.get_parent()==world.get_node("Actors/Residents"),String(id)+" visible only in correct home")
        await settled(actor)
        var step:HutorNpcRoutineStep=actor.current_step()
        var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
        check(actor.position.distance_to(step.position)<2,String(id)+" correct activity point")
        var expected:StringName=step.animation
        if expected==&"" or expected in [&"gesture_read",&"gesture_think"]:
            check(String(sprite.animation).begins_with("idle_"),String(id)+" honest static fallback for missing action frames")
        else:check(sprite.animation==expected,String(id)+" existing action clip actually plays: "+String(expected))
        var index:=actor.step_index
        var elapsed_wait:=actor.wait_left
        await frames(8)
        check(actor.wait_left<elapsed_wait and actor.step_index==index,String(id)+" action has a real duration")
        check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and sprite.scale==Vector2.ONE,String(id)+" original sharp body proportions")
        await shot(String(id)+"-work")
        # Exercise E selection as the player would, rather than starting a dialogue directly.
        var marker:HutorInteractable=actor.get_node("Interaction")
        var reachable:=false
        for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,-22),Vector2(0,35)]:
            hero.position=marker.global_position+offset;await frames()
            if free_at(world,hero.position) and hero.sensor.target==marker:reachable=true;break
        check(reachable,String(id)+" conversation reachable by E")
        if reachable:await tap_e();await create_timer(.28).timeout
        check(manager.is_active() and actor.state==HutorResident.State.TALKING,String(id)+" accepted dialogue stops occupation")
        if manager.is_active():
            var point:=actor.position;await frames(8)
            check(actor.position==point,String(id)+" speaker stops moving")
            await close_conversation(manager)
            check(actor.state!=HutorResident.State.TALKING and not hero.controls_locked,String(id)+" occupation and Hans resume")
        hero.position=world.get_node("Entry").position;await frames()
        check(travel.request_transition(r.schedule.home,true),String(id)+" existing home exit")
        await wait_transition()
    # Time passes across a scene change while the elder is talking.
    life.clock.seek(590);travel.request_transition(&"elder");await wait_transition()
    var elder:HutorResident=life.states[&"elder"].actor
    await settled(elder)
    var world:Node2D=travel.active_world;var hero:CharacterBody2D=world.player
    hero.interaction_requested.emit(elder.get_node("Interaction").interact());await create_timer(.28).timeout
    check(manager.is_active(),"time-boundary conversation starts")
    life.clock.seek(615)
    check(elder.state==HutorResident.State.TALKING,"clock jump does not interrupt an accepted dialogue")
    await close_conversation(manager)
    check(life.states[&"elder"].desired_scene==&"village" and life.states[&"elder"].mode==&"travel","after conversation elder follows current schedule instead of old paperwork")
    check(elder.current_step().position.distance_to(world.get_node("Exit").position)<32,"new goal is the actual exit")
    travel.request_transition(&"elder",true);await wait_transition()
    for id in life.states:check(life.states[id].actor.get_instance_id()==identities[id],String(id)+" keeps one identity through visits and conversations")
    print("RESULT: ",passed," occupation checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
