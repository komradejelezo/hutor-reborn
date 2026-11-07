extends "res://tests/verify_environment_depth.gd"
## Validate new multi-part architecture in the real shared/nested Y-sort tree.
func run() -> void:
    root.size = Vector2i(320,256)
    root.content_scale_size = root.size
    root.transparent_bg = true
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene = world
    world.atmosphere.set_effects_enabled(false)
    for light in world.find_children("*","PointLight2D",true,false): light.enabled = false
    for modulate in world.find_children("*","CanvasModulate",true,false): modulate.color = Color.WHITE
    for group in ["Ground","Ground Details","Extension Ground","New Paths","Ground Objects","Foreground","HUD"]: world.get_node(group).hide()
    for group in ["Structures","Nature","Props"]:
        for child in world.get_node("Actors/"+group).get_children(): child.hide()
    var player: CharacterBody2D = world.player
    player.set_physics_process(false)
    var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
    sprite.play("idle_down"); sprite.stop(); sprite.frame = 0
    var camera: Camera2D = player.get_node("Camera2D")
    camera.set_as_top_level(true); camera.position_smoothing_enabled = false
    camera.global_position = Vector2(1300,950); camera.force_update_scroll()
    var inn: Node2D = world.get_node("Actors/Structures/Inn")
    inn.show()
    for child in inn.get_children():
        if child is CanvasItem: child.hide()
    var cases := [
        [inn.get_node("Body"),110.0,22.0,"inn main building"],
        [inn.get_node("LeftWing"),55.0,18.0,"inn left wing"],
        [inn.get_node("RightWing"),55.0,18.0,"inn right wing"],
        [world.get_node("Actors/Structures/AbandonedHouse"),100.0,20.0,"abandoned house"],
        [world.get_node("Actors/Structures/HerbalistHouse"),90.0,20.0,"weathered herbalist house"],
        [world.get_node("Actors/Nature/CrookedPine"),35.0,20.0,"original landmark"],
    ]
    var audit: Array = []
    for data in cases:
        var target: Node2D = data[0]
        target.global_position = Vector2(1300,1000)
        for child in target.get_children():
            if child is CanvasItem and child.name != "Art": child.hide()
        for front in [false,true]:
            player.global_position = target.global_position + Vector2(0,data[2] if front else -data[1])
            player.hide(); target.show()
            var object_image := await capture()
            target.hide(); player.show()
            var player_image := await capture()
            target.show()
            var combined := await capture()
            var overlap := 0
            var wrong := 0
            for y in range(256):
                for x in range(320):
                    var a := object_image.get_pixel(x,y)
                    var b := player_image.get_pixel(x,y)
                    if a.a < .999 or b.a < .999 or a.is_equal_approx(b): continue
                    overlap += 1
                    var expected: Color = b if front else a
                    if not combined.get_pixel(x,y).is_equal_approx(expected): wrong += 1
            check(overlap >= 12 and wrong == 0, str(data[3])+": Hans "+("in front" if front else "behind")+" ("+str(overlap)+" opaque pixels)")
            audit.append({"kind":data[3],"front":front,"overlap":overlap,"wrong":wrong})
        target.hide()
    if not OS.get_cmdline_user_args().is_empty():
        var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify(audit,"  ",true))
    print("RESULT: ",passed," architectural depth checks passed, ",failed," failed")
    world.queue_free(); await process_frame
    quit(0 if failed == 0 else 1)
