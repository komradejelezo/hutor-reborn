extends "res://tests/verify_interiors.gd"
var output:="/tmp/brother5411"
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
    caption.text="5.4.11 DIAGNOSTIC PHYSICAL WALK / 37px/s / independent LEFT"
    sprite.speed_scale=1;var captured:=false
    var until:=Time.get_ticks_msec()+7000
    while actor.position.distance_to(goal)>1.3 and Time.get_ticks_msec()<until:
        var axis:=goal-actor.position;actor.velocity=axis.normalized()*minf(37,axis.length()*60)
        actor.face_point(actor.position+actor.velocity);actor.animator.apply("walk",actor.facing,&"",false)
        actor.move_and_slide();await physics_frame
        if not captured and sprite.frame==2:await shot("walk-"+String(actor.facing));captured=true
    check(actor.position.distance_to(goal)<2,"physical walk "+String(actor.facing))
    actor.velocity=Vector2.ZERO;actor.animator.apply("idle",actor.facing,&"",false);await create_timer(.3).timeout
func conversation(label:String) -> void:
    var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        hero.position=actor.position+offset;await frames(5)
        if free_at(world,hero.position) and hero.sensor.target==actor.get_node("Interaction"):chosen=true;break
    check(chosen,"original E reachable "+label)
    if not chosen:return
    var pos:=actor.position;var index:=actor.step_index
    await tap_e();await create_timer(2).timeout
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"existing conversation "+label)
    check(actor.position==pos and String(sprite.animation).begins_with("talk_"),"rise/put tool away before dialogue "+label)
    if dm.is_active():dm.window.reveal_all();await frames(5);await shot("dialogue-"+label);await create_timer(1).timeout;dm.close_dialogue()
    check(actor.step_index==index,"same activity resumes "+label)
    hero.position=Vector2(800,1100) if travel.active_id==&"" else Vector2(600,420)
func review_actions(wanted:Array,seconds:float,talk_clip:StringName=&"") -> void:
    var captured:Dictionary={};var complete:Dictionary={};var spoke:=false
    var until:=Time.get_ticks_msec()+int(seconds*1000)
    while Time.get_ticks_msec()<until:
        await physics_frame;view_at(actor.position+Vector2(20,-26))
        caption.text="5.4.11 REAL NPC / CLOCK FROZEN / "+actor.current_step().label+" / "+String(sprite.animation)
        if sprite.animation in wanted:
            if not captured.has(sprite.animation) and sprite.frame==mini(4,sprite.sprite_frames.get_frame_count(sprite.animation)-1):captured[sprite.animation]=true;await shot(String(sprite.animation))
            if sprite.frame==sprite.sprite_frames.get_frame_count(sprite.animation)-1:complete[sprite.animation]=true
            if sprite.animation==talk_clip and sprite.frame==4 and complete.has(talk_clip) and not spoke:
                spoke=true;await conversation(String(talk_clip))
        if complete.size()==wanted.size() and (talk_clip==&"" or spoke):
            await create_timer(.6).timeout;break
    check(complete.size()==wanted.size(),"full authored cycles reviewed "+str(wanted))
func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(450)
    world=travel.active_world;hero=world.player;actor=life.states[&"herbalist_brother"].actor;sprite=actor.get_node("AnimatedSprite2D")
    world.hud.hide();life._widget.hide();hero.set_physics_process(false)
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer);caption=Label.new();caption.position=Vector2(8,4);layer.add_child(caption)
    for r in life.states.values():r.actor.set_physics_process(false)
    actor.activity_controller.clear_props()
    var start:=Vector2(1000,1350);var found:=false
    for y in range(1320,1600,16):
        for x in range(900,1400,16):
            var clear:=true
            for dx in range(-8,152,8):
                for dy in range(-48,8,8):clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found,"free existing village floor for comparison")
    actor.position=start;var sister:HutorResident=life.states[&"herbalist"].actor;sister.position=start+Vector2(56,0);sister.get_node("AnimatedSprite2D").play("idle_down");sister.get_node("AnimatedSprite2D").pause()
    hero.position=start+Vector2(112,0);hero.sprite.play("idle_down");view_at(start+Vector2(56,-30))
    var approved:=sprite.sprite_frames;var material:=sprite.material
    sprite.sprite_frames=load("res://assets/npc/stage541/herbalist_brother/frames.tres");sprite.material=null;sprite.play("idle_down");sprite.stop()
    caption.text="5.4.11 DIAGNOSTIC BEFORE / brother - herbalist - Hans";await shot("comparison-before");await create_timer(.5).timeout
    sprite.sprite_frames=approved;sprite.material=material;actor.animator.apply("idle",&"down",&"",false)
    caption.text="5.4.11 DIAGNOSTIC AFTER / brother - herbalist - Hans";await shot("comparison-after");await create_timer(.5).timeout
    sister.position=start+Vector2(-88,22)
    hero.position=start+Vector2(-45,22)
    print("BROTHER5411_REVIEW_READY");await create_timer(.8).timeout
    for offset in [Vector2(64,0),Vector2(64,-48),Vector2(0,-48),Vector2.ZERO]:await gait(start+offset)
    life.clock.seek(360)
    for r in life.states.values():r.actor.set_physics_process(true)
    travel.request_transition(&"herbalist");await wait_transition();use_world()
    await review_actions([&"chop_wood",&"split_logs"],45,&"chop_wood")
    await review_actions([&"think"],25)
    life.clock.seek(1080);await review_actions([&"tired_idle"],20)
    check(sprite.scale==Vector2.ONE and sprite.position==Vector2.ZERO and sprite.offset==Vector2(-48,-82),"native grounded pivot")
    travel.request_transition(&"herbalist",true);await wait_transition();use_world()
    await route_review()
    print("RESULT: ",passed," graphical brother checks passed, ",failed," failed");quit(0 if failed==0 else 1)
func use_world() -> void:
    world=travel.active_world;hero=world.player;world.hud.hide();hero.set_physics_process(false)
    hero.position=Vector2(800,1100) if travel.active_id==&"" else Vector2(600,420)
    camera=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
func route_review() -> void:
    var r:HutorDailyResidentState=life.states[&"herbalist_brother"]
    life.clock.seek(479);life.clock.set_speed(8);life.clock.running=true
    var out_seen:=false;var in_seen:=false
    var until:=Time.get_ticks_msec()+45000
    while r.mode!=&"offsite" and Time.get_ticks_msec()<until:
        await physics_frame
        caption.text="5.4.11 REAL EXIT ROUTE / diagnostic time setup 07:59, speed8 / "+String(r.mode)
        if actor.is_inside_tree():view_at(actor.position+Vector2(18,-28))
        if r.mode==&"boundary_out" and not out_seen:out_seen=true;await shot("boundary-out")
    check(r.mode==&"offsite" and not actor.is_inside_tree(),"real departure, no body/new map at offsite logging")
    await shot("offsite")
    # Keep the existing residency state; advance intent rather than scrub/teleport.
    life.clock.absolute_minutes=1080;life._tick(1080);life.clock.set_speed(4)
    until=Time.get_ticks_msec()+60000
    while not (r.scene==&"herbalist" and r.mode==&"local") and Time.get_ticks_msec()<until:
        await physics_frame
        caption.text="5.4.11 REAL RETURN ROUTE / diagnostic offsite clock jump 18:00 / "+String(r.mode)
        if actor.is_inside_tree():view_at(actor.position+Vector2(18,-28))
        if r.mode==&"boundary_in" and not in_seen:in_seen=true;await shot("boundary-in")
    life.clock.running=false;life.clock.set_speed(1)
    check(out_seen and in_seen,"both physical map boundary directions captured")
    check(r.scene==&"herbalist" and r.mode==&"local" and r.event_counts.get("return_from_work",0)>0,"original route returns worker to shared home")
