extends SceneTree
## Focused screenshots for A-04..A-11, not a fresh audit or input test.
var destination:="/tmp/visual-fixes"
func _initialize() -> void:
    if not OS.get_cmdline_user_args().is_empty():destination=OS.get_cmdline_user_args()[0]
    call_deferred("run")
func frames(n:int=4) -> void:
    for i in n:await process_frame
    await RenderingServer.frame_post_draw
func shot(name:String) -> void:
    await frames()
    root.get_texture().get_image().save_png(destination+"/"+name+".png")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(destination)
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world);current_scene=world;await frames(8)
    world.hud.hide();world.player.set_physics_process(false)
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.position_smoothing_enabled=false;camera.set_as_top_level(true)
    for view in [["storehouse-apron",Vector2(1287,1110)],["smoke",Vector2(936,697)],["forest",Vector2(1287,1750)]]:
        camera.global_position=view[1];camera.force_update_scroll();await shot(view[0])
    camera.set_as_top_level(false);world.player.set_physics_process(true)
    var travel:Node=root.get_node("InteriorTravel")
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        travel.request_transition(id)
        while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        room.hud.hide();room.player.set_physics_process(false)
        camera=room.player.get_node("Camera2D")
        camera.position_smoothing_enabled=false;camera.set_as_top_level(true)
        camera.global_position=room.room_bounds.get_center();camera.force_update_scroll();await shot(String(id))
        camera.set_as_top_level(false);room.player.set_physics_process(true)
        travel.request_transition(id,true)
        while travel.busy:await process_frame
    print("PASS: focused before/after cameras captured for village and six interiors")
    quit()
