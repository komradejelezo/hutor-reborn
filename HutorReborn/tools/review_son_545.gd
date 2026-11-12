extends "res://tests/verify_interiors.gd"
## Diagnostic review uses existing worlds and bodies. Captions distinguish
## natural AI from arranged comparison/physical gait measurements.
var output:="/tmp/son545"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var hero:CharacterBody2D
var caption:Label
var camera:Camera2D
var ids:Dictionary={}
var shots:Dictionary={}

func capture(label:String) -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+label+".png")

func bind_world() -> void:
    world=travel.active_world;hero=world.player;world.hud.hide();hero.set_physics_process(false)
    actor=life.states[&"woodcutter_son"].actor;sprite=actor.get_node("AnimatedSprite2D")
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false

func view_actor() -> void:
    camera.global_position=actor.position+Vector2(0,-42);camera.force_update_scroll()

func natural(seconds:float,label:String) -> void:
    caption.text="5.4.5 NATURAL AI (clock frozen) / "+label
    var until:=Time.get_ticks_msec()+int(seconds*1000)
    while Time.get_ticks_msec()<until:
        await physics_frame;view_actor()
        var phase:String=actor.get("play_phase")
        if phase in ["kick","pickup","jump","inspect"] and not shots.has(label+phase) and sprite.frame>0:
            shots[label+phase]=true;await capture(label+"-"+phase)

func gait(goal:Vector2,running:bool) -> void:
    caption.text="5.4.5 DIAGNOSTIC PHYSICS / "+("RUN 77.5" if running else "WALK 34.1")
    sprite.speed_scale=1;actor.animator.prefer_run=running
    var until:=Time.get_ticks_msec()+5000
    while actor.position.distance_to(goal)>1.3 and Time.get_ticks_msec()<until:
        var axis:=goal-actor.position;var speed:=77.5 if running else 34.1
        actor.velocity=axis.normalized()*minf(speed,axis.length()*60)
        actor.face_point(actor.position+actor.velocity)
        actor.animator.apply("walk",actor.facing,&"",false);actor.move_and_slide();await physics_frame
    check(actor.position.distance_to(goal)<2,"diagnostic physical "+("run " if running else "walk ")+String(actor.facing))
    actor.velocity=Vector2.ZERO;actor.animator.apply("idle",actor.facing,&"",false);await create_timer(.25).timeout

func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer)
    caption=Label.new();caption.position=Vector2(8,4);caption.add_theme_font_size_override("font_size",14);layer.add_child(caption)
    life.clock.seek(600);await frames(8);bind_world();life._widget.hide()
    hero.position=Vector2(1400,1300)
    print("SON545_REVIEW_READY")
    await natural(68,"yard")
    check(actor.get("play_counts").has("chase"),"natural yard AI actually chases a kicked ball")
    for r in life.states.values():r.actor.set_physics_process(false)
    actor._clear_game();actor.state=actor.State.WAITING;sprite.position=Vector2.ZERO
    var start:=Vector2.ZERO;var found:=false
    for y in range(1400,1750,16):
        for x in range(1100,1550,16):
            var clear:=true
            for dx in range(-16,200,8):
                for dy in range(-48,48,8):clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found,"collision checked comparison/gait corridor")
    actor.position=start;hero.position=start+Vector2(50,0);hero.sprite.play("idle_down")
    camera.global_position=start+Vector2(80,-40);camera.force_update_scroll()
    var parked:Array=[]
    for i in 2:
        var adult:HutorResident=life.states[&"woodcutter" if i==0 else &"woodcutter_wife"].actor
        parked.append([adult,adult.get_parent(),adult.position]);adult.reparent(world.get_node("Actors/Residents"),false)
        adult.position=start+Vector2(105+i*50,0);adult.animator.apply("idle",&"down",&"",false)
    var approved:=sprite.sprite_frames
    sprite.sprite_frames=load("res://assets/npc/stage541/woodcutter_son/frames.tres");sprite.play("idle_down");sprite.stop()
    var material:=sprite.material;sprite.material=null
    caption.text="5.4.5 DIAGNOSTIC COMPARISON / BEFORE: son - Hans - father - mother"
    await capture("family-before");await create_timer(.6).timeout
    sprite.sprite_frames=approved;sprite.material=material;actor.animator.apply("idle",&"down",&"",false)
    caption.text="5.4.5 DIAGNOSTIC COMPARISON / AFTER: son - Hans - father - mother"
    await capture("family-after");await create_timer(1).timeout
    for data in parked:data[0].reparent(data[1],false);data[0].position=data[2]
    hero.position=start+Vector2(-55,30);view_actor()
    for running in [false,true]:
        for offset in [Vector2(64,0),Vector2(64,-32),Vector2(0,-32),Vector2.ZERO]:await gait(start+offset,running)
    # Actual six-frame foot pivot and no fake repeated padding.
    check(sprite.offset==Vector2(-48,-82) and sprite.scale==Vector2.ONE,"uniform native body anchored at feet")
    # Existing family home and existing evening activity, not a new interior.
    life.clock.seek(1085)
    check(travel.request_transition(&"woodcutter"),"existing home loads");await wait_transition()
    bind_world();hero.position=Vector2(650,450)
    for r in life.states.values():r.actor.set_physics_process(true)
    await natural(10,"home")
    actor.set_physics_process(false);actor.velocity=Vector2.ZERO
    var marker:HutorInteractable=actor.get_node("Interaction");var chosen:=false
    for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,32)]:
        hero.position=marker.global_position+offset;await frames(5)
        if free_at(world,hero.position) and hero.sensor.target==marker:chosen=true;break
    check(chosen,"existing E target selects original boy in home")
    if chosen:
        caption.text="5.4.5 EXISTING DIALOGUE / synthetic E in review fixture"
        await tap_e();await create_timer(.4).timeout
        var manager:Node=root.get_node("DialogueManager")
        check(manager.is_active() and actor.state==actor.State.TALKING,"dialogue stops original boy")
        if manager.is_active():
            manager.window.reveal_all();await capture("dialogue")
            check(manager.window.portrait.size==Vector2(128,192),"new portrait displays at native aspect and size")
            await create_timer(1).timeout;manager.close_dialogue();await frames(10)
        check(actor.state!=actor.State.TALKING,"conversation releases occupation")
    for id in life.states:check(life.states[id].actor.get_instance_id()==ids[id],"unchanged original resident identity: "+String(id))
    print("RESULT: ",passed," son graphical review checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
