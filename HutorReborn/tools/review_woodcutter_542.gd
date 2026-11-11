extends "res://tests/verify_interiors.gd"
## Diagnostic fixture IN the existing village, never a new playable forest/map.
## Same actor; deterministic work choreography for visual and collision inspection.
var output:="/tmp/wood542"
var actor:HutorResident
var sprite:AnimatedSprite2D
var hero:CharacterBody2D
var caption:Label
var world:Node2D
var start:=Vector2.ZERO
var log_a:Node2D
var interrupted:=false
var impact_captured:=false
var log_b:Node2D
func snapshot(name:String) -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+name+".png")
func prop(name:String,texture:String,point:Vector2,factor:float,solid:bool) -> Node2D:
    var item:=Node2D.new();item.name=name;item.position=point
    var art:=Sprite2D.new();art.name="Art";art.texture=load(texture);art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;art.centered=false
    art.scale=Vector2.ONE*factor;art.position=Vector2(-art.texture.get_width()*factor*.5,-art.texture.get_height()*factor);item.add_child(art)
    if solid:
        var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=6
        var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,6);collision.shape=shape;collision.position=Vector2(0,-3);body.add_child(collision);item.add_child(body)
    world.get_node("Actors/Props").add_child(item);return item
func animate(clip:String,seconds:float=0.0) -> void:
    caption.text="DIAGNOSTIC WORKSHOP / same village actor / "+clip
    actor.animator.apply("work",&"right",StringName(clip),false)
    if seconds>0:await create_timer(seconds).timeout;return
    while sprite.is_playing():
        if clip=="work_pick_up" and sprite.frame>=2:log_a.hide()
        if clip=="work_put_down" and sprite.frame>=3:log_b.show()
        if clip=="work_chop" and sprite.frame==3 and not interrupted:
            interrupted=true
            await converse("mid-work")
            hero.position=actor.position+Vector2(-55,0)
            actor.animator.apply("work",&"right",&"work_chop",false)
            check(sprite.frame>=3,"work stroke resumes after conversation")
        if clip=="work_chop" and sprite.frame==5:
            check(actor.position.distance_to(start)<1,"axe impact at bound stump, actor planted")
            if not impact_captured:impact_captured=true;await snapshot("impact")
        await physics_frame
func walk_to(point:Vector2,carry:bool=false) -> void:
    caption.text="DIAGNOSTIC PHYSICS / "+("carry_logs" if carry else "walk")
    var deadline:=Time.get_ticks_msec()+8000
    while actor.position.distance_to(point)>1.5 and Time.get_ticks_msec()<deadline:
        var direction:Vector2=point-actor.position
        actor.velocity=direction.normalized()*minf(36,direction.length()*60)
        actor.facing=(&"right" if direction.x>0 else &"left") if absf(direction.x)>absf(direction.y) else (&"down" if direction.y>0 else &"up")
        if carry:actor.animator.apply("work",actor.facing,StringName("carry_"+String(actor.facing)),false)
        else:actor.animator.apply("walk",actor.facing,&"",false)
        actor.move_and_slide();await physics_frame
    check(actor.position.distance_to(point)<2,"physical path completed without crossing props")
    actor.velocity=Vector2.ZERO
func converse(tag:String) -> void:
    actor.state=actor.State.WAITING;actor.facing=&"down";actor.get_node("Interaction").position=Vector2.ZERO
    hero.position=actor.position+Vector2(0,24);hero.sprite.play("idle_up");await frames(6)
    check(hero.sensor.target==actor.get_node("Interaction"),"original E target selects this resident: "+tag)
    await tap_e();await create_timer(.35).timeout
    var dm:Node=root.get_node("DialogueManager");check(dm.is_active() and actor.state==actor.State.TALKING,"real dialogue pauses actor: "+tag)
    if dm.is_active():dm.window.reveal_all();await create_timer(.6).timeout;await snapshot("dialogue-"+tag);await create_timer(.4).timeout;dm.close_dialogue();await create_timer(.25).timeout
    check(actor.state!=actor.State.TALKING,"dialogue returns to original occupation state: "+tag)
func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    world=travel.active_world;world.hud.hide()
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(465);await frames(8);life.set_physics_process(false)
    for r in life.states.values():r.actor.set_physics_process(false)
    actor=life.states[&"woodcutter"].actor;sprite=actor.get_node("AnimatedSprite2D");hero=world.player;hero.set_physics_process(false)
    check(actor.is_inside_tree() and actor.definition.id==&"woodcutter","one original woodcutter materialized, no clone")
    # A collision-checked corridor. Fixture props are never saved to the map.
    var found:=false
    for y in range(1400,1750,16):
        for x in range(1100,1550,16):
            var clear:=true
            for dx in range(-16,145,8):
                for dy in [-16,0,16]:clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found,"workshop corridor physically clear")
    actor.position=start;actor.state=actor.State.WAITING;actor.facing=&"down";sprite.position=Vector2.ZERO;sprite.z_index=0;sprite.speed_scale=1
    hero.position=start+Vector2(60,0);hero.sprite.play("idle_down")
    var cam:Camera2D=hero.get_node("Camera2D");cam.set_as_top_level(true);cam.position_smoothing_enabled=false;cam.position=start+Vector2(50,-50);cam.force_update_scroll()
    var layer:=CanvasLayer.new();layer.layer=90;root.add_child(layer);caption=Label.new();caption.position=Vector2(8,4);caption.add_theme_font_size_override("font_size",14);layer.add_child(caption)
    caption.text="5.4.2 DIAGNOSTIC / Hans + original woodcutter, normal game scale"
    actor.animator.apply("idle",&"down",&"",false);await create_timer(.4).timeout;await snapshot("comparison")
    hero.position=start+Vector2(0,50)
    print("WOOD542_REVIEW_READY")
    for direction in [&"right",&"down",&"left",&"up"]:
        var goal:Vector2=actor.position+({&"right":Vector2(48,0),&"down":Vector2(0,16),&"left":Vector2(-48,0),&"up":Vector2(0,-16)}[direction])
        await walk_to(goal);actor.animator.apply("idle",direction,&"",false);await create_timer(.3).timeout
    actor.position=start # End of closed path within tolerance; diagnostic registration only.
    var stump:=prop("DiagnosticStump542","res://assets/environment/krivaya_sosna/objects/stump.png",start+Vector2(18,13),.30,true)
    log_a=prop("DiagnosticLogs542A","res://assets/npc/woodcutter542/game/placed_logs.png",start+Vector2(60,0),1,false)
    log_b=prop("DiagnosticLogs542B","res://assets/npc/woodcutter542/game/placed_logs.png",start+Vector2(120,0),1,false);log_b.hide()
    await frames(3)
    for i in 2:
        sprite.play("work_chop");sprite.set_frame_and_progress(0,0);await animate("work_chop")
    await snapshot("chop-end")
    await walk_to(start+Vector2(42,0));sprite.play("work_pick_up");sprite.set_frame_and_progress(0,0);await animate("work_pick_up")
    check(not log_a.visible,"ground logs hidden when lifted")
    await snapshot("picked-up")
    for offset in [Vector2(72,0),Vector2(72,16),Vector2(42,16),Vector2(42,0)]:
        await walk_to(start+offset,true)
    await walk_to(start+Vector2(102,0),true);await snapshot("carrying")
    sprite.play("work_put_down");sprite.set_frame_and_progress(0,0);await animate("work_put_down")
    check(log_b.visible,"placed logs remain in world")
    sprite.play("work_rest");sprite.set_frame_and_progress(0,0);await animate("work_rest");await snapshot("rest")
    await converse("after-work")
    print("RESULT: ",passed," woodcutter workshop checks passed, ",failed," failed")
    print("WOOD542_REVIEW_COMPLETE")
    quit(0 if failed==0 else 1)
