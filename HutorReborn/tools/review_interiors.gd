extends SceneTree
var travel: Node
var destination := "/tmp/interior"
func _initialize() -> void:
    if not OS.get_cmdline_user_args().is_empty():destination=OS.get_cmdline_user_args()[0]
    call_deferred("run")
func frames(count: int = 4) -> void:
    for i in count: await process_frame
func screenshot(suffix: String) -> void:
    await frames();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(destination+"-"+suffix+".png")
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(village);current_scene=village
    await frames(6)
    for id in [&"inn",&"elder",&"herbalist"]:
        travel.request_transition(id)
        while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        room.hud.hide()
        room.player.set_physics_process(false)
        root.size=Vector2i(1280,800);root.content_scale_size=root.size
        var camera:Camera2D=room.player.get_node("Camera2D")
        camera.position_smoothing_enabled=false
        camera.set_as_top_level(true);camera.global_position=room.room_bounds.get_center()
        camera.force_update_scroll()
        await screenshot(String(id))
        if id==&"inn":
            var npc:HutorResident=room.get_node("Actors/Residents").resident(&"innkeeper")
            room.hud.show()
            room.player.position=npc.get_node("Interaction").global_position+Vector2(0,20)
            await frames()
            room.player.interaction_requested.emit(npc.get_node("Interaction").interact())
            await create_timer(.26).timeout
            root.get_node("DialogueManager").window.reveal_all()
            root.size=Vector2i(960,540);root.content_scale_size=root.size
            await screenshot("inn-dialogue")
            root.get_node("DialogueManager").close_dialogue()
            await create_timer(.2).timeout
        camera.set_as_top_level(false)
        room.player.set_physics_process(true)
        travel.request_transition(id,true)
        while travel.busy:await process_frame
    print("PASS: three authentic interior captures and existing dialogue UI saved")
    quit()
