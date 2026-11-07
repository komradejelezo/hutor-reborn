extends "res://tools/review_surfaces.gd"
## Read-only captures and audit, with the normal atmosphere visible.
func run() -> void:
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var file := FileAccess.open(destination + "-audit.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"scene_state":snapshot(world)}, "  ", true))
    file.close()
    var player: CharacterBody2D = world.player
    player.set_physics_process(false)
    await frames(12)
    save_image("gameplay")
    world.hud.hide()
    var camera: Camera2D = player.get_node("Camera2D")
    camera.position_smoothing_enabled = false
    camera.position = Vector2.ZERO
    root.size = world.map_size
    root.content_scale_size = world.map_size
    camera.force_update_scroll()
    await frames()
    save_image("overview")
    root.size = Vector2i(960,540)
    root.content_scale_size = root.size
    camera.set_as_top_level(true)
    var views := {
        "elder":[Vector2(950,780),Vector2(936,775)],
        "woodcutter":[Vector2(1720,780),Vector2(1713,775)],
        "storehouse":[Vector2(1287,1280),Vector2(1287,1242)],
        "old-man":[Vector2(880,1650),Vector2(858,1650)],
        "herbalist":[Vector2(1800,1650),Vector2(1717,1650)],
        "inn":[Vector2(1688,2180),Vector2(1688,2290)],
        "abandoned":[Vector2(2700,960),Vector2(2710,1080)]}
    for key in views:
        player.position = views[key][1]
        camera.global_position = views[key][0]
        camera.force_update_scroll()
        await frames()
        save_image(key)
    world.queue_free()
    await process_frame
    quit()
