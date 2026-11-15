extends "res://tests/verify_interiors.gd"
var output:="/tmp/oldman549"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var hero:CharacterBody2D
var camera:Camera2D
var caption:Label
func shot(label:String) -> void:
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+label+".png")
func view_at(pos:Vector2) -> void:
    camera.position=pos;camera.force_update_scroll()
func gait(goal:Vector2) -> void:
    caption.text="5.4.9 DIAGNOSTIC PHYSICAL WALK / 18px/s / staff RIGHT, pipe LEFT"
    sprite.speed_scale=1;var captured:=false
    var until:=Time.get_ticks_msec()+8000
    while actor.position.distance_to(goal)>1.3 and Time.get_ticks_msec()<until:
        var axis:=goal-actor.position;actor.velocity=axis.normalized()*minf(18,axis.length()*60)
        actor.face_point(actor.position+actor.velocity);actor.animator.apply("walk",actor.facing,&"",false)
        actor.move_and_slide();await physics_frame
        if not captured and sprite.frame==2:await shot("walk-"+String(actor.facing));captured=true
    check(actor.position.distance_to(goal)<2,"physical walk "+String(actor.facing))
    actor.velocity=Vector2.ZERO;actor.animator.apply("idle",actor.facing,&"",false);await create_timer(.25).timeout
func conversation() -> void:
    var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        hero.position=actor.position+offset;await frames(5)
        if free_at(world,hero.position) and hero.sensor.target==actor.get_node("Interaction"):chosen=true;break
    check(chosen,"original E beside seat")
    if not chosen:return
    var position:=actor.position;var index:=actor.step_index
    await tap_e();await create_timer(3).timeout
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"original conversation after standing up")
    check(actor.position==position and not actor.get_node("PipeSmoke").emitting,"no feet displacement or smoking while speaking")
    check(String(sprite.animation).begins_with("talk_") and not sprite.flip_h,"independent directed conversation")
    if dm.is_active():dm.window.reveal_all();await frames(5);await shot("dialogue");await create_timer(1).timeout;dm.close_dialogue()
    check(actor.step_index==index,"same activity after talk")
    hero.position=Vector2(800,1100)
func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(360)
    world=travel.active_world;hero=world.player;actor=life.states[&"old_man"].actor;sprite=actor.get_node("AnimatedSprite2D")
    world.hud.hide();life._widget.hide();hero.set_physics_process(false)
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer);caption=Label.new();caption.position=Vector2(8,4);layer.add_child(caption)
    for r in life.states.values():r.actor.set_physics_process(false)
    actor.activity_controller.clear_props()
    var start:=Vector2(1000,1350);var found:=false
    for y in range(1320,1600,16):
        for x in range(900,1400,16):
            var clear:=true
            for dx in range(-8,88,8):
                for dy in range(-40,8,8):clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found,"free existing village floor for comparison")
    actor.position=start;hero.position=start+Vector2(56,0);hero.sprite.play("idle_down");view_at(start+Vector2(28,-30))
    var approved:=sprite.sprite_frames;var material:=sprite.material
    sprite.sprite_frames=load("res://assets/npc/stage541/old_man/frames.tres");sprite.material=null;sprite.play("idle_down");sprite.stop()
    caption.text="5.4.9 DIAGNOSTIC COMPARISON BEFORE / old man - Hans";await shot("comparison-before");await create_timer(.6).timeout
    sprite.sprite_frames=approved;sprite.material=material;actor.animator.apply("idle",&"down",&"",false)
    caption.text="5.4.9 DIAGNOSTIC COMPARISON AFTER / old man - Hans";await shot("comparison-after");await create_timer(.8).timeout
    hero.position=start+Vector2(-45,22)
    print("OLDMAN549_REVIEW_READY");await create_timer(.8).timeout
    for offset in [Vector2(48,0),Vector2(48,-32),Vector2(0,-32),Vector2.ZERO]:await gait(start+offset)
    life.clock.seek(360);hero.position=Vector2(800,1100)
    for r in life.states.values():r.actor.set_physics_process(true)
    var clips:Dictionary={};var spoke:=false;var puff:=false;var until:=Time.get_ticks_msec()+110000
    while Time.get_ticks_msec()<until:
        await physics_frame;view_at(actor.position+Vector2(18,-24))
        caption.text="5.4.9 REAL NPC / CLOCK FROZEN / "+actor.current_step().label+" / "+String(sprite.animation)
        if sprite.animation in [&"smoke_pipe",&"sit_down",&"sit_smoke",&"sit_idle",&"stand_up",&"think"]:
            var key:=String(sprite.animation)
            if not clips.has(key) and sprite.frame==mini(4,sprite.sprite_frames.get_frame_count(sprite.animation)-1):clips[key]=true;await shot(key)
        if actor.get_node("PipeSmoke").emitting:puff=true
        if sprite.animation==&"sit_smoke" and sprite.frame==4 and not spoke:spoke=true;await conversation()
        if clips.size()==6 and spoke and puff:break
    check(clips.size()==6 and puff,"all six actions and real particle emission reviewed over time")
    life.clock.seek(1080);travel.request_transition(&"old_man");await wait_transition()
    world=travel.active_world;hero=world.player;world.hud.hide();hero.set_physics_process(false);hero.position=Vector2(600,390)
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    var home_seen:=false
    for i in 600:
        await physics_frame;view_at(actor.position+Vector2(20,-28));caption.text="5.4.9 ORIGINAL HOME / hearth activity (clock seek setup)"
        if sprite.animation==&"smoke_pipe" and sprite.frame==4:await shot("home");home_seen=true;break
    check(home_seen,"existing home hearth action")
    check(sprite.scale==Vector2.ONE and sprite.position==Vector2.ZERO and sprite.offset==Vector2(-48,-82),"unchanged native grounded pivot")
    print("RESULT: ",passed," graphical old-man checks passed, ",failed," failed");quit(0 if failed==0 else 1)
