extends "res://tests/verify_interiors.gd"
## Read-only art/physics measurements of the existing inn.
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(600)
    travel.request_transition(&"inn");await wait_transition()
    var world:Node2D=travel.active_world
    var nav:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
    var grid:=nav.grid_for(Rect2())
    for point in [Vector2(776,280),Vector2(776,296),Vector2(670,350),Vector2(670,344),Vector2(300,340),Vector2(260,354),Vector2(630,364),Vector2(712,344)]:
        print("MEASURE ",point," free=",free_at(world,point,5)," baked=",grid.is_point_solid(nav.cell(point))," safe=",grid.get_point_position(nav.closest_cell(grid,point)))
    for key in ["TableA","TableB","TableC","Fireplace"]:
        var item:Node2D=world.get_node("Actors/Props/"+key)
        print("OBJECT ",key," pos=",item.position," art=",item.get_node("Art").position," tex=",item.get_node("Art").texture.get_size()," collider=",item.get_node("Solid/Feet").position," shape=",item.get_node("Solid/Feet").shape.size)
    for r in life.states.values():r.actor.set_physics_process(false)
    world.player.set_physics_process(false);world.hud.hide();life._widget.hide()
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.position=Vector2(530,310);camera.force_update_scroll()
    if DisplayServer.get_name()!="headless":
        await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("/workspace/work/stage547/inn-before.png")
    quit()
