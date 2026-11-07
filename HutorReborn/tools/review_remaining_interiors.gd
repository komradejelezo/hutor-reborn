extends "res://tools/review_interiors.gd"
## Actual saved 4.5 rooms. No forced old-man presence or placeholder residents.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(village);current_scene=village;await frames(6)
    for id in [&"woodcutter",&"old_man",&"storehouse"]:
        travel.request_transition(id)
        while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        room.hud.hide();room.player.set_physics_process(false)
        root.size=Vector2i(960,640);root.content_scale_size=root.size
        var camera:Camera2D=room.player.get_node("Camera2D")
        camera.position_smoothing_enabled=false;camera.set_as_top_level(true)
        camera.global_position=room.room_bounds.get_center();camera.force_update_scroll()
        await screenshot(String(id))
        camera.set_as_top_level(false);room.player.set_physics_process(true)
        travel.request_transition(id,true)
        while travel.busy:await process_frame
    print("PASS: three original-resource compact rooms captured through existing transitions")
    quit()
