extends "res://tests/verify_interiors.gd"
## Existing actor/worlds only. Natural work checks and diagnostic choreography are labelled.
var output:="/tmp/wife544"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var hero:CharacterBody2D
var caption:Label
var baseline_ids:Dictionary={}
var start:=Vector2.ZERO
var basket_a:Sprite2D
var basket_b:Sprite2D
var counters:Dictionary={}

func capture(label:String) -> void:
    caption.text="5.4.4 / "+label
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+label+".png")

func freeze() -> void:
    life.clock.running=false;life.set_physics_process(false);life._widget.hide()
    for r in life.states.values():r.actor.set_physics_process(false)
    world=travel.active_world;hero=world.player;hero.set_physics_process(false);world.hud.hide()
    actor=life.states[&"woodcutter_wife"].actor;sprite=actor.get_node("AnimatedSprite2D")

func camera_at(point:Vector2) -> void:
    var camera:Camera2D=hero.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.position=point;camera.force_update_scroll()

func original_action(minute:float, action:String, clip:String) -> void:
    life.clock.running=false;life.clock.seek(minute);await frames(6)
    world=travel.active_world;hero=world.player
    actor=life.states[&"woodcutter_wife"].actor;sprite=actor.get_node("AnimatedSprite2D")
    actor.set_physics_process(true)
    var deadline:=Time.get_ticks_msec()+6000
    while actor.state!=actor.State.WAITING and Time.get_ticks_msec()<deadline:await physics_frame
    freeze();hero.position=actor.position+Vector2(70,35);camera_at(actor.position+Vector2(30,-45))
    actor.activity_controller.reactions.reset_attention();actor._present()
    await create_timer(.8).timeout
    check(actor.current_step().label==action,"existing schedule action: "+action)
    check(sprite.animation==StringName(clip) or (clip=="work_laundry" and sprite.animation==&"work_kneel_down"),"new body performs bound action: "+action)
    check(free_at(world,actor.position,actor.definition.foot_radius),"work foot position is outside furniture: "+action)
    await capture("natural-"+action)

func walk_to(goal:Vector2, carry:=false) -> void:
    caption.text="5.4.4 DIAGNOSTIC PHYSICS / "+("carry basket" if carry else "walk")
    var deadline:=Time.get_ticks_msec()+8000
    while actor.position.distance_to(goal)>1.5 and Time.get_ticks_msec()<deadline:
        var direction:=goal-actor.position
        actor.velocity=direction.normalized()*minf(32,direction.length()*60)
        actor.facing=(&"right" if direction.x>0 else &"left") if absf(direction.x)>absf(direction.y) else (&"down" if direction.y>0 else &"up")
        if carry:actor.animator.apply("work",actor.facing,&"work_carry",false)
        else:actor.animator.apply("walk",actor.facing,&"",false)
        actor.move_and_slide();await physics_frame
    actor.velocity=Vector2.ZERO
    check(actor.position.distance_to(goal)<2,"same-speed physical path completed")

func action(clip:String,seconds:=0.0) -> void:
    caption.text="5.4.4 DIAGNOSTIC / "+clip
    actor.animator.set_work_context("review/"+clip)
    actor.animator.apply("work",&"right",StringName(clip),false)
    if seconds>0:
        await create_timer(seconds).timeout
        return
    while sprite.is_playing():
        if clip=="pick_up_basket" and sprite.frame>=1:basket_a.hide()
        if clip=="put_down_basket" and sprite.frame>=3:basket_b.show()
        await physics_frame

func ground_basket(point:Vector2) -> Sprite2D:
    var item:=Sprite2D.new();item.texture=load("res://assets/npc/woodcutter_wife544/game/basket_ground.png")
    item.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;item.material=sprite.material
    item.centered=false;item.position=point+Vector2(-6,-11)
    check(item.texture!=null,"prepared floor basket imports correctly")
    world.get_node("Actors/Props").add_child(item)
    return item

func conversation(label:String) -> void:
    actor.state=actor.State.WAITING;actor.facing=&"down";actor.get_node("Interaction").position=Vector2.ZERO
    hero.position=actor.position+Vector2(0,23);hero.sprite.play("idle_up");await frames(5)
    check(hero.sensor.target==actor.get_node("Interaction"),"existing E target selects wife: "+label)
    await tap_e();await create_timer(.35).timeout
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active() and actor.state==actor.State.TALKING,"real dialogue holds original actor: "+label)
    if manager.is_active():
        for i in 40:actor._present();await physics_frame
        check(sprite.animation!=&"work_stand_up","drawn rise completes into directed conversation")
        manager.window.reveal_all();check(manager.window.portrait.size==Vector2(128,192),"approved portrait displays 1:1")
        await capture("dialogue-"+label);await create_timer(.6).timeout;manager.close_dialogue();await create_timer(.3).timeout
    check(actor.state!=actor.State.TALKING,"conversation returns occupation ownership: "+label)
    hero.position=actor.position+Vector2(-70,25)

func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false
    for id in life.states:baseline_ids[id]=life.states[id].actor.get_instance_id()
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer)
    caption=Label.new();caption.position=Vector2(8,4);caption.add_theme_font_size_override("font_size",14);layer.add_child(caption)
    await original_action(605,"sweep_yard","work_sweep")
    await conversation("yard-sweep")
    await original_action(615,"household","work_laundry")
    # Render-only entry must reach the original washing clip, not loop forever.
    for i in 50:actor._present();await physics_frame
    check(sprite.animation==&"work_laundry","drawn kneel entry finishes into real washing loop")
    await conversation("laundry")
    for i in 35:actor._present();await physics_frame
    await original_action(905,"garden_work","work_rake")
    # Original residents, diagnostic registration for a direct scale comparison.
    var found:=false
    for y in range(1400,1750,16):
        for x in range(1100,1550,16):
            var clear:=true
            for dx in range(-16,160,8):
                for dy in [-16,0,16]:clear=clear and free_at(world,Vector2(x+dx,y+dy),7)
            if clear:start=Vector2(x,y);found=true;break
        if found:break
    check(found,"collision-checked review corridor exists")
    actor.position=start;actor.state=actor.State.WAITING;actor.facing=&"down";sprite.position=Vector2.ZERO
    hero.position=start+Vector2(55,0);hero.sprite.play("idle_down");camera_at(start+Vector2(55,-45))
    var wood:HutorResident=life.states[&"woodcutter"].actor
    var parking:=wood.get_parent();var saved_position:=wood.position;var saved_state:=wood.state
    wood.reparent(world.get_node("Actors/Residents"),false);wood.position=start+Vector2(110,0);wood.set_physics_process(false)
    wood.animator.apply("idle",&"down",&"",false);actor.animator.apply("idle",&"down",&"",false)
    await capture("comparison-wife-Hans-woodcutter")
    check(wood.get_node("AnimatedSprite2D").scale==Vector2.ONE*1.08 and hero.speed==94,"approved woodcutter and Hans scales remain intact")
    wood.reparent(parking,false);wood.position=saved_position;wood.state=saved_state
    hero.position=start+Vector2(-50,25)
    print("WIFE544_REVIEW_READY")
    for offset in [Vector2(48,0),Vector2(48,16),Vector2(0,16),Vector2.ZERO]:
        await walk_to(start+offset);actor.animator.apply("idle",actor.facing,&"",false);await create_timer(.3).timeout
    await action("work_sweep",1.4);await capture("sweep-loop")
    await action("work_rake",1.2)
    await action("work_rest");check(not sprite.is_playing(),"rest settles without automatic gesture restart")
    await conversation("after-rest")
    basket_a=ground_basket(start+Vector2(60,0));basket_b=ground_basket(start+Vector2(120,0));basket_b.hide()
    await walk_to(start+Vector2(44,0));await action("pick_up_basket")
    check(not basket_a.visible,"floor basket disappears on real grasp pose")
    await walk_to(start+Vector2(104,0),true);await capture("carry-basket")
    await action("put_down_basket");check(basket_b.visible,"released basket remains after empty-handed settle")
    await capture("basket-placed")
    # Existing home: actual cook point and existing household/serve occupations.
    life.clock.seek(425);check(travel.request_transition(&"woodcutter"),"existing family home loads");await wait_transition()
    await original_action(425,"cook","work_cook")
    var pot:Node2D=world.get_node("Actors/Props/KitchenPot")
    check(actor.position.distance_to(pot.position)<32,"cooking is bound to the original pot, not air")
    await conversation("home-cook")
    await original_action(373,"serve","work_sort")
    await original_action(1100,"household","work_laundry")
    # Table wipe is prepared, demonstrated at the actual table, not added to schedule.
    var table:Node2D=world.get_node("Actors/Props/DiningTable")
    actor.position=table.position+Vector2(-45,-28);sprite.position=Vector2.ZERO;sprite.z_index=1
    hero.position=actor.position+Vector2(-50,25);camera_at(actor.position+Vector2(60,-30))
    check(free_at(world,actor.position,actor.definition.foot_radius),"diagnostic table approach stays outside table collision")
    await action("work_wipe",1.5);await capture("diagnostic-table-wipe");sprite.z_index=0
    for id in life.states:check(life.states[id].actor.get_instance_id()==baseline_ids[id],"same original resident identity: "+String(id))
    print("RESULT: ",passed," wife world/work/interaction checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
