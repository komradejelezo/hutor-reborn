extends "res://tests/verify_interiors.gd"
func picture() -> Image:
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(365)
    travel.request_transition(&"inn");await wait_transition()
    var world:Node2D=travel.active_world;var actor:HutorResident=life.states[&"innkeeper"].actor
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    world.player.position=Vector2(580,440);world.player.set_physics_process(false)
    for i in 600:
        await physics_frame
        if sprite.animation==&"work_wipe" and sprite.frame==3:break
    check(actor.position.distance_to(Vector2(424,240))<2,"physical final approach reaches real rear working edge")
    check(free_at(world,Vector2(424,240),5),"rear working lane is physically free")
    check(not free_at(world,Vector2(424,252),5),"counter base remains solid")
    check(free_at(world,Vector2(424,274),5),"front guest lane stays free")
    for r in life.states.values():r.actor.set_physics_process(false)
    world.atmosphere.set_effects_enabled(false)
    for item in world.find_children("*","CPUParticles2D",true,false):item.emitting=false;item.hide()
    for item in world.find_children("*","PointLight2D",true,false):item.enabled=false
    for item in world.find_children("*","CanvasModulate",true,false):item.color=Color.WHITE
    sprite.pause()
    var overlay:Sprite2D=world.get_node("Actors/Props/Counter/InnkeeperHands546")
    overlay.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.position=actor.position+Vector2(20,-20);camera.force_update_scroll()
    actor.hide();overlay.hide();var table:=await picture()
    actor.show();overlay.hide();var behind:=await picture()
    overlay.show();var working:=await picture()
    var point:Vector2=actor.get_global_transform_with_canvas().origin
    var foot_changes:=0;var hand_changes:=0
    for y in range(int(point.y-9),int(point.y+1)):
        for x in range(int(point.x-7),int(point.x+8)):
            if not table.get_pixel(x,y).is_equal_approx(working.get_pixel(x,y)):foot_changes+=1
    for y in range(int(point.y-27),int(point.y-10)):
        for x in range(int(point.x-24),int(point.x+24)):
            if not behind.get_pixel(x,y).is_equal_approx(working.get_pixel(x,y)):hand_changes+=1
    check(foot_changes==0,"boots remain behind the counter: "+str(foot_changes)+" wrong pixels")
    check(hand_changes>3,"working arms/cloth appear above the countertop: "+str(hand_changes)+" pixels")
    check(sprite.position==Vector2.ZERO and sprite.z_index==0,"no foot translation or global body z override")
    if not OS.get_cmdline_user_args().is_empty():
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify({"wrong_foot_pixels":foot_changes,"visible_hand_pixels":hand_changes,"position":[actor.position.x,actor.position.y]},"  "))
    print("RESULT: ",passed," counter registration checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
