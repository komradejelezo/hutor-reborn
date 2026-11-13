extends "res://tests/verify_interiors.gd"
## Four real workplaces, selected through clock seek for a compact art review.
func run() -> void:
    var output:="/tmp/inn546-workstations"
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    travel.request_transition(&"inn");await wait_transition()
    var world:Node2D=travel.active_world;world.hud.hide();life._widget.hide()
    var hero:CharacterBody2D=world.player;hero.position=Vector2(580,440);hero.set_physics_process(false)
    var actor:HutorResident=life.states[&"innkeeper"].actor;var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var camera:Camera2D=hero.get_node("Camera2D");camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer);var caption:=Label.new();caption.position=Vector2(8,4);layer.add_child(caption)
    print("INN546_WORKSTATIONS_READY")
    await create_timer(.8).timeout # Give an external recorder time to attach after loading.
    for pair in [[365,"work_wipe"],[600,"work_mug"],[607,"work_serve"],[612,"work_cook"]]:
        life.clock.seek(pair[0]);caption.text="5.4.6 NATURAL AI / selected schedule action (clock seek) / "+pair[1]
        var captured:=false;var phases:Dictionary={}
        for i in 330:
            await physics_frame
            camera.position=actor.position+Vector2(25,-28);camera.force_update_scroll()
            if sprite.animation==StringName(pair[1]):
                phases[sprite.frame]=true
                if sprite.frame==3 and not captured:
                    await process_frame;await RenderingServer.frame_post_draw
                    root.get_texture().get_image().save_png(output+"-"+pair[1]+".png");captured=true
        check(captured and phases.size()>=6,"real drawn action over time: "+pair[1])
    print("RESULT: ",passed," workstation visual checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
