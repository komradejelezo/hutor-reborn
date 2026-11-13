extends "res://tests/verify_interiors.gd"
func run() -> void:
    var output:="/tmp/inn546-hearth"
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(612)
    travel.request_transition(&"inn");await wait_transition()
    var world:Node2D=travel.active_world;world.hud.hide();life._widget.hide()
    var actor:HutorResident=life.states[&"innkeeper"].actor;var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var hero:CharacterBody2D=world.player;hero.set_physics_process(false);hero.position=Vector2(580,440)
    var camera:Camera2D=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.position=actor.position+Vector2(25,-25);camera.force_update_scroll()
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer);var caption:=Label.new();caption.position=Vector2(8,4);caption.text="5.4.6 NATURAL AI / small clay crock at hearth";layer.add_child(caption)
    var shots:Dictionary={}
    for i in 360:
        await physics_frame
        if sprite.animation==&"work_cook" and sprite.frame in [2,3,4] and not shots.has(sprite.frame):
            shots[sprite.frame]=true;await process_frame;await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"-"+str(sprite.frame)+".png")
    check(shots.size()==3,"drawn spoon is reviewed over three actual frames at the visible crock")
    print("RESULT: ",passed," hearth review checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
