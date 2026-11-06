extends "res://tools/review_surfaces.gd"
## Preview/audit only. The real scene is never saved or configured by this tool.
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var state:=snapshot(world)
    await frames(12)
    var file:=FileAccess.open(destination+"-audit.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"scene_state":state},"  ",true))
    file.close()
    save_image("gameplay")
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position_smoothing_enabled=false
    camera.position=Vector2.ZERO
    world.get_node("HUD").hide()
    root.size=world.map_size
    root.content_scale_size=world.map_size
    camera.zoom=Vector2.ONE
    camera.force_update_scroll()
    await frames()
    save_image("overview")
    world.atmosphere.set_effects_enabled(false)
    player.hide()
    root.size=Vector2i(960,540)
    root.content_scale_size=Vector2i(960,540)
    var views:Dictionary={"elder":Vector2(950,780),"miller":Vector2(1720,780),"common":Vector2(1287,1280),"hunter":Vector2(880,1650),"herbalist":Vector2(1800,1650),"pine":Vector2(510,760),"north":Vector2(1050,350),"forest":Vector2(2150,1100)}
    for key in views:
        player.position=views[key]
        camera.force_update_scroll()
        await frames()
        save_image(key)
    world.queue_free()
    await process_frame
    quit()
