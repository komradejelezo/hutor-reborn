extends "res://tools/review_surfaces.gd"
## Read-only captures with atmosphere enabled, identical framing and visible Hans.
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var state:=snapshot(world)
    var file:=FileAccess.open(destination+"-audit.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"scene_state":state},"  ",true))
    file.close()
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    await frames(12)
    save_image("gameplay")
    world.get_node("HUD").hide()
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position_smoothing_enabled=false
    camera.position=Vector2.ZERO
    root.size=world.map_size
    root.content_scale_size=world.map_size
    camera.force_update_scroll()
    await frames()
    save_image("overview")
    root.size=Vector2i(960,540)
    root.content_scale_size=root.size
    camera.set_as_top_level(true)
    var views:Dictionary={
        "plaza":[Vector2(1378,1362),Vector2(1378,1442)],
        "elder":[Vector2(950,780),Vector2(936,775)],
        "miller":[Vector2(1720,780),Vector2(1713,775)],
        "common":[Vector2(1287,1280),Vector2(1287,1242)],
        "hunter":[Vector2(880,1650),Vector2(858,1650)],
        "herbalist":[Vector2(1800,1650),Vector2(1717,1650)],
        "pine":[Vector2(510,720),Vector2(560,917)],
        "north":[Vector2(1387,270),Vector2(1387,198)],
        "gate":[Vector2(1287,1800),Vector2(1287,1865)]}
    for key in views:
        player.position=views[key][1]
        camera.global_position=views[key][0]
        camera.force_update_scroll()
        await frames()
        save_image(key)
    world.queue_free()
    await process_frame
    quit()
