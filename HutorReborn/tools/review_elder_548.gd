extends "res://tests/verify_interiors.gd"
## Existing worlds/bodies. Captions separate arranged comparisons from natural AI.
var output:="/tmp/inn548"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var hero:CharacterBody2D
var camera:Camera2D
var caption:Label
var shots:Dictionary={}
var ids:Dictionary={}

func capture(label:String) -> void:
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+label+".png")

func view_at(point:Vector2) -> void:
    camera.position=point;camera.force_update_scroll()

func gait(goal:Vector2) -> void:
    caption.text="5.4.8 DIAGNOSTIC PHYSICS / WALK 30px/s"
    sprite.speed_scale=1;actor.animator.prefer_run=false
    var until:=Time.get_ticks_msec()+6500
    while actor.position.distance_to(goal)>1.3 and Time.get_ticks_msec()<until:
        var axis:=goal-actor.position
        actor.velocity=axis.normalized()*minf(30,axis.length()*60)
        actor.face_point(actor.position+actor.velocity);actor.animator.apply("walk",actor.facing,&"",false)
        actor.move_and_slide();await physics_frame
    check(actor.position.distance_to(goal)<2,"physical walk "+String(actor.facing))
    actor.velocity=Vector2.ZERO;actor.animator.apply("idle",actor.facing,&"",false);await create_timer(.25).timeout

func conversation(label:String) -> void:
    var marker:HutorInteractable=actor.get_node("Interaction");var selected:=false
    for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,30)]:
        hero.position=marker.global_position+offset;await frames(5)
        if hero.sensor.target==marker and free_at(world,hero.position):selected=true;break
    check(selected,"existing reachable E target "+label)
    if not selected:return
    await tap_e();await create_timer(.5).timeout
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active() and actor.state==actor.State.TALKING,"existing dialogue stops body "+label)
    if manager.is_active():
        manager.window.reveal_all();await frames(20)
        check(not String(sprite.animation).begins_with("work_"),"put-down finishes into calm conversation")
        check(manager.window.portrait.size==Vector2(128,192),"portrait uses native aspect and size")
        await capture("dialogue-"+label);await create_timer(1).timeout;manager.close_dialogue();await frames(10)
        check(actor.state!=actor.State.TALKING,"original occupation released "+label)
    hero.position=Vector2(580,440)

func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(408)
    check(travel.request_transition(&"elder"),"existing elder entry");await wait_transition()
    world=travel.active_world;hero=world.player;actor=life.states[&"elder"].actor;sprite=actor.get_node("AnimatedSprite2D")
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    world.hud.hide();life._widget.hide();hero.set_physics_process(false)
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer)
    caption=Label.new();caption.position=Vector2(8,4);caption.add_theme_font_size_override("font_size",14);layer.add_child(caption)
    for r in life.states.values():r.actor.set_physics_process(false)
    for r in life.states.values():
        if r.actor!=actor:r.actor.hide() # Diagnostic comparison only; no actor is moved.
    actor.activity_controller.clear_props()
    var start:=Vector2.ZERO;var found:=false
    for y in range(350,int(world.room_bounds.end.y)-24,16):
        for x in range(int(world.room_bounds.position.x)+24,int(world.room_bounds.end.x)-136,16):
            var clear:=true
            for dx in range(-8,80,8):
                for dy in range(-40,8,8):clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found and world.room_bounds.has_point(start) and world.room_bounds.has_point(start+Vector2(64,-32)),"free comparison and gait corridor on the approved room floor")
    actor.position=start;hero.position=start+Vector2(56,0);hero.sprite.play("idle_down")
    view_at(start+Vector2(28,-32));var approved:=sprite.sprite_frames;var material:=sprite.material
    sprite.sprite_frames=load("res://assets/npc/stage541/elder/frames.tres");sprite.material=null;sprite.play("idle_down");sprite.stop()
    caption.text="5.4.8 DIAGNOSTIC COMPARISON / BEFORE: elder - Hans"
    await capture("comparison-before");await create_timer(.6).timeout
    sprite.sprite_frames=approved;sprite.material=material;actor.animator.apply("idle",&"down",&"",false)
    caption.text="5.4.8 DIAGNOSTIC COMPARISON / AFTER: elder - Hans"
    await capture("comparison-after");await create_timer(.8).timeout
    hero.position=start+Vector2(-45,22)
    print("ELDER548_REVIEW_READY")
    for offset in [Vector2(64,0),Vector2(64,-32),Vector2(0,-32),Vector2.ZERO]:await gait(start+offset)
    life.clock.seek(408);hero.position=Vector2(580,440)
    for r in life.states.values():r.actor.show();r.actor.set_physics_process(true)
    var until:=Time.get_ticks_msec()+75000;var spoke:Dictionary={}
    var distance:=actor.distance_walked
    while Time.get_ticks_msec()<until:
        await physics_frame
        view_at(actor.position+Vector2(25,-28));caption.text="5.4.8 NATURAL AI (clock frozen) / "+actor.current_step().label+" / "+String(sprite.animation)
        if sprite.animation in [&"work_read",&"work_write",&"work_think"] and sprite.frame==3:
            var label:=String(sprite.animation)
            if not shots.has(label):shots[label]=true;await capture(label)
            if not spoke.has(label) and sprite.animation in [&"work_read",&"work_write"]:
                spoke[label]=true;await conversation(label)
        if shots.size()==3:break
    check(shots.size()==3 and actor.distance_walked-distance>100,"real indoor route, reading, journal and reflection")
    # Outside art review: setup via seek is explicit; subsequent walking is real AI.
    check(travel.request_transition(&"elder",true),"existing hero exit for outdoor review");await wait_transition()
    world=travel.active_world;hero=world.player;camera=hero.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false;hero.set_physics_process(false)
    life.clock.seek(600);hero.position=Vector2(1500,1660)
    var outdoor_until:=Time.get_ticks_msec()+38000;var saw_inspect:=false;var saw_point:=false
    while Time.get_ticks_msec()<outdoor_until:
        await physics_frame;view_at(actor.position+Vector2(25,-28))
        caption.text="5.4.8 REAL AI / OUTDOORS (clock seek setup) / "+String(sprite.animation)
        if sprite.animation==&"work_inspect" and sprite.frame==3 and not saw_inspect:
            saw_inspect=true;await capture("inspection")
        if String(sprite.animation).begins_with("point_") and sprite.frame==2 and not saw_point:
            saw_point=true;await capture("gesture")
        if saw_inspect and saw_point:break
    check(saw_inspect,"real outdoor inspection over time")
    # A close actual resident may not pass during a short recording. The work
    # regression separately verifies the directed gesture with a labelled fixture.
    if not saw_point:
        # Wait for the natural route to reach a stop; placing a fixture relative
        # to a moving actor would leave the partner behind before the gesture.
        for i in 1800:
            await physics_frame;view_at(actor.position+Vector2(25,-28))
            if actor.state==actor.State.WAITING:break
        var partner:HutorResident=life.states[&"woodcutter_son"].actor
        var old_position:=partner.position;var processing:=partner.is_physics_processing()
        partner.set_physics_process(false);partner.position=actor.position+Vector2(65,15)
        actor.activity_controller.visual54._point_cooldown=0
        caption.text="5.4.8 DIAGNOSTIC NEARBY-RESIDENT FIXTURE / directed gesture"
        for i in 900:
            await physics_frame;view_at(actor.position+Vector2(25,-28))
            if String(sprite.animation).begins_with("point_") and sprite.frame==2:
                saw_point=true;await capture("gesture");await create_timer(.8).timeout;break
        partner.position=old_position;partner.set_physics_process(processing)
    check(saw_point,"directed gesture with visible nearby resident")
    # Lighting comparisons use the original village lights, explicitly arranged.
    var outside_start:=actor.position
    for minute in [665,1100]:
        life.clock.seek(minute);await frames(6);actor.set_physics_process(false)
        var village:Node2D=travel.active_world
        if actor.get_parent()!=village.get_node("Actors/Residents"):
            # Evening residency is indoors. Capture the actual room instead of
            # moving an inactive resident into a location it does not inhabit.
            travel.request_transition(&"elder");await wait_transition();world=travel.active_world
            camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
            actor.set_physics_process(false);hero.set_physics_process(false)
        view_at(actor.position+Vector2(24,-28));caption.text="5.4.8 ORIGINAL LIGHT / "+("day" if minute==665 else "evening indoors")
        await capture("day" if minute==665 else "evening")
    check(sprite.offset==Vector2(-48,-82) and sprite.scale==Vector2.ONE and sprite.position==Vector2.ZERO,"unchanged grounded pivot and uniform native scale")
    for id in life.states:check(life.states[id].actor.get_instance_id()==ids[id],"original resident identity "+String(id))
    print("RESULT: ",passed," elder graphical checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
