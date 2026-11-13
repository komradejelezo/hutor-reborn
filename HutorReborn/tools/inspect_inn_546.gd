extends "res://tests/verify_interiors.gd"
## Read-only measurement of the existing working surfaces and route clearance.
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(425)
    travel.request_transition(&"inn");await wait_transition()
    var world:Node2D=travel.active_world
    var nav:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
    var grid:=nav.grid_for(Rect2())
    for point in [Vector2(696,264),Vector2(680,264),Vector2(696,280),Vector2(600,216),Vector2(424,216)]:
        var cell:=nav.cell(point)
        print("MEASURE ",point," clear=",free_at(world,point,5)," baked_solid=",grid.is_point_solid(cell)," safe=",grid.get_point_position(nav.closest_cell(grid,point)))
    for name in ["Counter","Fireplace","CounterJug","KitchenClay","KitchenPots"]:
        var object:Node2D=world.get_node("Actors/Props/"+name)
        print("OBJECT ",name," pos=",object.position," art=",object.get_node("Art").position)
    for r in life.states.values():r.actor.set_physics_process(false)
    world.player.set_physics_process(false);world.hud.hide()
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.position=Vector2(530,290);camera.force_update_scroll()
    if DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().is_empty():
        await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
    quit()
