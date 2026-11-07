extends "res://tools/review_surfaces.gd"
## Read-only world/NPC captures. No scene or resource is saved by this utility.
func run() -> void:
    var world: Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene=world
    var file:=FileAccess.open(destination+"-audit.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"scene_state":snapshot(world)},"  ",true)); file.close()
    await frames(20)
    save_image("gameplay")
    var population: Node2D=world.get_node("Actors/Residents")
    for npc in population.residents.values(): npc.set_physics_process(false)
    world.player.set_physics_process(false)
    var camera: Camera2D=world.player.get_node("Camera2D")
    camera.position_smoothing_enabled=false; camera.position=Vector2.ZERO
    world.hud.hide()
    root.size=world.map_size; root.content_scale_size=world.map_size
    camera.force_update_scroll(); await frames()
    save_image("overview")
    root.size=Vector2i(960,540); root.content_scale_size=root.size
    camera.set_as_top_level(true)
    var views: Dictionary={"elder":Vector2(950,800),"inn-family":Vector2(1780,2280),"woodcutter-family":Vector2(1713,850),"herbalist-family":Vector2(1830,1660),"old-man":Vector2(560,910)}
    for name in views:
        camera.global_position=views[name]; camera.force_update_scroll()
        await frames(); save_image(name)
    # A real resident, real adapter and the existing window. Role portraits fall back.
    var old_man: HutorResident=population.resident(&"old_man")
    old_man.step_index=0; old_man.position=old_man.current_step().position
    old_man.state=old_man.State.WAITING; old_man._present()
    world.player.position=old_man.position+Vector2(0,34)
    camera.global_position=old_man.position+Vector2(0,60); camera.force_update_scroll()
    await frames(); save_image("pipe")
    world.player.interaction_requested.emit(old_man.get_node("Interaction").interact())
    await create_timer(.25).timeout
    var manager: Node=root.get_node("DialogueManager")
    manager.window.reveal_all()
    await frames(); save_image("dialogue")
    manager.close_dialogue(); await create_timer(.16).timeout
    world.queue_free(); await process_frame
    quit()
